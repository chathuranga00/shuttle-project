package com.shuttle.notification.fcm;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.config.NotificationProperties;
import com.shuttle.domain.repository.DeviceTokenRepository;
import io.jsonwebtoken.Jwts;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class FcmPushService {

    private final NotificationProperties notificationProperties;
    private final DeviceTokenRepository deviceTokenRepository;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    private String cachedProjectId;
    private String cachedClientEmail;
    private PrivateKey cachedPrivateKey;
    private String cachedAccessToken;
    private Instant tokenExpiry = Instant.MIN;
    private boolean initialized = false;
    private boolean enabled = false;

    public FcmPushService(
            NotificationProperties notificationProperties,
            DeviceTokenRepository deviceTokenRepository,
            ObjectMapper objectMapper
    ) {
        this.notificationProperties = notificationProperties;
        this.deviceTokenRepository = deviceTokenRepository;
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
        initFirebase();
    }

    private synchronized void initFirebase() {
        if (initialized) {
            return;
        }
        initialized = true;

        String credentialsJson = notificationProperties.firebaseCredentials();
        String credentialsPath = notificationProperties.firebaseConfigPath();

        if (credentialsJson == null || credentialsJson.isBlank()) {
            credentialsJson = System.getenv("FIREBASE_CREDENTIALS");
        }
        if (credentialsPath == null || credentialsPath.isBlank()) {
            credentialsPath = System.getenv("FIREBASE_CONFIG_PATH");
        }

        try {
            InputStream inputStream = null;
            if (credentialsJson != null && !credentialsJson.isBlank()) {
                inputStream = new java.io.ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8));
            } else if (credentialsPath != null && !credentialsPath.isBlank()) {
                inputStream = new FileInputStream(credentialsPath);
            }

            if (inputStream != null) {
                try (InputStream is = inputStream) {
                    JsonNode root = objectMapper.readTree(is);
                    cachedProjectId = root.path("project_id").asText();
                    cachedClientEmail = root.path("client_email").asText();
                    String privateKeyPem = root.path("private_key").asText();

                    if (!cachedProjectId.isBlank() && !cachedClientEmail.isBlank() && !privateKeyPem.isBlank()) {
                        cachedPrivateKey = parsePrivateKey(privateKeyPem);
                        enabled = true;
                        log.info("FCM push service initialized successfully for project: {}", cachedProjectId);
                    }
                }
            } else {
                log.info("No Firebase credentials provided. FCM push notifications will run in mock mode.");
            }
        } catch (Exception e) {
            log.warn("Failed to initialize Firebase credentials (running in mock mode): {}", e.getMessage());
            enabled = false;
        }
    }

    public void sendPush(String token, String title, String body, Map<String, String> data) {
        if (token == null || token.isBlank()) {
            return;
        }

        if (!enabled) {
            log.info("[FCM Mock] Push sent to token {}: {} - {}", token, title, body);
            return;
        }

        try {
            String accessToken = getAccessToken();
            if (accessToken == null) {
                log.warn("Unable to obtain Google OAuth2 token for FCM; falling back to mock log.");
                log.info("[FCM Mock] Push sent to token {}: {} - {}", token, title, body);
                return;
            }

            Map<String, Object> messageMap = new HashMap<>();
            messageMap.put("token", token);

            Map<String, String> notificationMap = new HashMap<>();
            notificationMap.put("title", title);
            notificationMap.put("body", body);
            messageMap.put("notification", notificationMap);

            if (data != null && !data.isEmpty()) {
                messageMap.put("data", data);
            }

            Map<String, Object> payload = Map.of("message", messageMap);
            String jsonPayload = objectMapper.writeValueAsString(payload);

            String url = "https://fcm.googleapis.com/v1/projects/" + cachedProjectId + "/messages:send";
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Authorization", "Bearer " + accessToken)
                    .header("Content-Type", "application/json; UTF-8")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                    .timeout(Duration.ofSeconds(10))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 200) {
                log.debug("FCM push sent successfully to token: {}", token);
            } else if (response.statusCode() == 404 || response.statusCode() == 400 && response.body().contains("UNREGISTERED")) {
                log.info("Device token is unregistered or invalid; removing from repository: {}", token);
                deviceTokenRepository.deleteByToken(token);
            } else {
                log.warn("FCM push failed with HTTP {}: {}", response.statusCode(), response.body());
            }
        } catch (Exception e) {
            log.warn("Error sending FCM push to token {}: {}", token, e.getMessage());
        }
    }

    public void sendMulticast(List<String> tokens, String title, String body, Map<String, String> data) {
        if (tokens == null || tokens.isEmpty()) {
            return;
        }
        for (String token : tokens) {
            sendPush(token, title, body, data);
        }
    }

    private synchronized String getAccessToken() {
        if (cachedAccessToken != null && Instant.now().isBefore(tokenExpiry.minusSeconds(60))) {
            return cachedAccessToken;
        }

        try {
            Instant now = Instant.now();
            Date issuedAt = Date.from(now);
            Date expiresAt = Date.from(now.plusSeconds(3600));

            String jwt = Jwts.builder()
                    .issuer(cachedClientEmail)
                    .subject(cachedClientEmail)
                    .audience().add("https://oauth2.googleapis.com/token").and()
                    .claim("scope", "https://www.googleapis.com/auth/firebase.messaging")
                    .issuedAt(issuedAt)
                    .expiration(expiresAt)
                    .signWith(cachedPrivateKey)
                    .compact();

            String requestBody = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" + jwt;

            HttpRequest tokenRequest = HttpRequest.newBuilder()
                    .uri(URI.create("https://oauth2.googleapis.com/token"))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .timeout(Duration.ofSeconds(10))
                    .build();

            HttpResponse<String> response = httpClient.send(tokenRequest, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 200) {
                JsonNode tokenNode = objectMapper.readTree(response.body());
                cachedAccessToken = tokenNode.path("access_token").asText();
                int expiresIn = tokenNode.path("expires_in").asInt(3600);
                tokenExpiry = Instant.now().plusSeconds(expiresIn);
                return cachedAccessToken;
            } else {
                log.warn("OAuth2 token request failed with status {}: {}", response.statusCode(), response.body());
            }
        } catch (Exception e) {
            log.warn("Exception generating FCM OAuth2 token: {}", e.getMessage());
        }
        return null;
    }

    private PrivateKey parsePrivateKey(String pem) throws Exception {
        String cleanPem = pem.replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s+", "");
        byte[] keyBytes = Base64.getDecoder().decode(cleanPem);
        PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(keyBytes);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return kf.generatePrivate(spec);
    }

    public boolean isEnabled() {
        return enabled;
    }
}

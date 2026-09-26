package com.shuttle.security;

import com.shuttle.config.JwtProperties;
import com.shuttle.domain.entity.RefreshToken;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.repository.RefreshTokenRepository;
import com.shuttle.exception.ApiException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Date;
import java.util.HexFormat;
import java.util.UUID;
import javax.crypto.SecretKey;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class JwtService {

    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_USER_ID = "userId";

    private final JwtProperties jwtProperties;
    private final RefreshTokenRepository refreshTokenRepository;

    private SecretKey signingKey;

    @PostConstruct
    void init() {
        signingKey = Keys.hmacShaKeyFor(
                jwtProperties.secret().getBytes(StandardCharsets.UTF_8));
    }

    // -------------------------------------------------------------------------
    // Access token
    // -------------------------------------------------------------------------

    /** Generate a short-lived access token (15 min by default). */
    public String generateAccessToken(User user) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(user.getEmail())
                .claim(CLAIM_USER_ID, user.getId())
                .claim(CLAIM_ROLE, user.getRole().name())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusMillis(jwtProperties.expirationMs())))
                .signWith(signingKey)
                .compact();
    }

    /** Parse and validate an access token. Returns the Claims on success. */
    public Claims parseAccessToken(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(signingKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (ExpiredJwtException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_EXPIRED", "Access token has expired.");
        } catch (JwtException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_INVALID", "Access token is invalid.");
        }
    }

    public Long getUserIdFromToken(String token) {
        return parseAccessToken(token).get(CLAIM_USER_ID, Long.class);
    }

    public String getRoleFromToken(String token) {
        return parseAccessToken(token).get(CLAIM_ROLE, String.class);
    }

    public String getEmailFromToken(String token) {
        return parseAccessToken(token).getSubject();
    }

    // -------------------------------------------------------------------------
    // Refresh token
    // -------------------------------------------------------------------------

    /**
     * Generate a cryptographically random refresh token, persist a hashed copy,
     * and return the raw (unhashed) value to send to the client.
     */
    @Transactional
    public String generateRefreshToken(User user) {
        String rawToken = UUID.randomUUID().toString();
        String hash = sha256Hex(rawToken);

        RefreshToken entity = new RefreshToken();
        entity.setUser(user);
        entity.setTokenHash(hash);
        entity.setExpiresAt(Instant.now().plusMillis(jwtProperties.refreshExpirationMs()));
        entity.setRevoked(false);
        refreshTokenRepository.save(entity);

        return rawToken;
    }

    /**
     * Validate an incoming raw refresh token.
     * Throws ApiException on invalid / expired / revoked.
     * Returns the persisted entity so the caller can obtain the associated User.
     */
    @Transactional
    public RefreshToken validateRefreshToken(String rawToken) {
        String hash = sha256Hex(rawToken);
        RefreshToken entity = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_INVALID", "Refresh token not found."));

        if (entity.isRevoked()) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_REVOKED", "Refresh token has been revoked.");
        }
        if (entity.getExpiresAt().isBefore(Instant.now())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_EXPIRED", "Refresh token has expired.");
        }
        // Rotate: revoke current token
        entity.setRevoked(true);
        refreshTokenRepository.save(entity);
        return entity;
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static String sha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}

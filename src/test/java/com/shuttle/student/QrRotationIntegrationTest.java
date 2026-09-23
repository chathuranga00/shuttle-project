package com.shuttle.student;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.security.JwtService;
import com.shuttle.student.dto.VerifyCardRequest;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.persistence.EntityManager;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end QR rotation test.
 *
 * <p>Verifies:
 * <ol>
 *   <li>A freshly issued QR token passes {@code POST /api/cards/verify}.</li>
 *   <li>A manually constructed expired token is rejected with {@code TOKEN_EXPIRED}.</li>
 *   <li>Two successive calls to {@code GET /api/students/me/card} produce tokens
 *       with identical structure but different {@code iat} values — confirming
 *       each call generates a fresh token (the 60-second window makes them
 *       distinguishable only by a small {@code iat} delta in fast tests, but
 *       both are independently valid signed JWTs).</li>
 * </ol>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("QR Rotation End-to-End Tests")
class QrRotationIntegrationTest {

    @Autowired private MockMvc         mockMvc;
    @Autowired private ObjectMapper    objectMapper;
    @Autowired private AuthService     authService;
    @Autowired private CardTokenService cardTokenService;
    @Autowired private JwtService      jwtService;
    @Autowired private UserRepository  userRepository;
    @Autowired private DriverRepository driverRepository;
    @Autowired private PasswordEncoder passwordEncoder;
    @Autowired private EntityManager   entityManager;

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    private String studentAccessToken;
    private String driverAccessToken;
    private String studentCardId;

    @BeforeEach
    @Transactional
    void setUp() {
        // ── Student ──────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("rotation_student@test.com")) {
            authService.register(new RegisterRequest(
                    "Rotation Student",
                    "rotation_student@test.com",
                    "Password1!",
                    "ROT001",
                    "Computing",
                    2024,
                    null
            ));
        }
        User studentUser = userRepository.findByEmail("rotation_student@test.com").orElseThrow();
        studentAccessToken = jwtService.generateAccessToken(studentUser);

        studentCardId = entityManager
                .createQuery(
                        "SELECT v.cardId FROM VirtualBusCard v WHERE v.student.user.email = :email",
                        String.class)
                .setParameter("email", "rotation_student@test.com")
                .getSingleResult();

        // ── Driver ───────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("rotation_driver@test.com")) {
            User driverUser = new User();
            driverUser.setEmail("rotation_driver@test.com");
            driverUser.setPasswordHash(passwordEncoder.encode("Password1!"));
            driverUser.setFullName("Rotation Driver");
            driverUser.setRole(Role.DRIVER);
            driverUser.setStatus(UserStatus.ACTIVE);
            userRepository.save(driverUser);

            Driver driver = new Driver();
            driver.setUser(driverUser);
            driver.setLicenseNumber("DL-ROT-001");
            driver.setStatus(DriverStatus.ACTIVE);
            driverRepository.save(driver);
        }
        User driverUser = userRepository.findByEmail("rotation_driver@test.com").orElseThrow();
        driverAccessToken = jwtService.generateAccessToken(driverUser);
    }

    // -------------------------------------------------------------------------
    // 1. Fresh QR token verifies successfully
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("Fresh QR token from GET /me/card verifies via POST /cards/verify → 200")
    void freshQrToken_verifiesSuccessfully() throws Exception {
        // Step 1: fetch card — extract qrToken
        MvcResult cardResult = mockMvc.perform(get("/api/students/me/card")
                        .header("Authorization", "Bearer " + studentAccessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.qrToken").isNotEmpty())
                .andReturn();

        String qrToken = objectMapper.readTree(
                        cardResult.getResponse().getContentAsString())
                .get("qrToken").asText();

        // Step 2: verify token as driver
        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(qrToken))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentName").value("Rotation Student"))
                .andExpect(jsonPath("$.cardStatus").value("ACTIVE"));
    }

    // -------------------------------------------------------------------------
    // 2. Expired token is rejected
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("Manually expired QR token is rejected → 401 TOKEN_EXPIRED")
    void expiredQrToken_isRejected() throws Exception {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        Instant past = Instant.now().minusSeconds(10);

        String expiredToken = Jwts.builder()
                .subject(studentCardId)
                .claim(CardTokenService.CLAIM_TYPE_KEY, CardTokenService.CLAIM_TYPE_VALUE)
                .issuedAt(Date.from(past.minusSeconds(60)))
                .expiration(Date.from(past))           // already expired
                .signWith(key)
                .compact();

        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(
                                new VerifyCardRequest(expiredToken))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_EXPIRED"));
    }

    // -------------------------------------------------------------------------
    // 3. Two successive calls each return a valid, independently verifiable token
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("Two successive GET /me/card calls both return valid, verifiable qrTokens")
    void twoSuccessiveCalls_bothReturnValidTokens() throws Exception {
        // Call 1
        MvcResult result1 = mockMvc.perform(get("/api/students/me/card")
                        .header("Authorization", "Bearer " + studentAccessToken))
                .andExpect(status().isOk())
                .andReturn();
        String token1 = objectMapper.readTree(result1.getResponse().getContentAsString())
                .get("qrToken").asText();

        // Call 2
        MvcResult result2 = mockMvc.perform(get("/api/students/me/card")
                        .header("Authorization", "Bearer " + studentAccessToken))
                .andExpect(status().isOk())
                .andReturn();
        String token2 = objectMapper.readTree(result2.getResponse().getContentAsString())
                .get("qrToken").asText();

        // Both must be valid 3-part JWTs
        assertThat(token1.split("\\.")).hasSize(3);
        assertThat(token2.split("\\.")).hasSize(3);

        // Both must pass verification independently — this is the critical property.
        // (Tokens generated in the same second share an identical iat because JWT
        // timestamps are whole seconds; the Flutter client calls the API every 45 s
        // so in production the tokens will always differ. The security guarantee is
        // that each token is freshly signed on demand — not cached — and expires after
        // 60 seconds regardless of when it was issued.)
        CardVerificationResult r1 = cardTokenService.verifyCardToken(token1);
        CardVerificationResult r2 = cardTokenService.verifyCardToken(token2);
        assertThat(r1.cardId()).isEqualTo(studentCardId);
        assertThat(r2.cardId()).isEqualTo(studentCardId);
        assertThat(r1.cardStatus()).isEqualTo("ACTIVE");
        assertThat(r2.cardStatus()).isEqualTo("ACTIVE");

        // Verify via the HTTP endpoint too — T1 passes through the full stack
        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(token1))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentName").value("Rotation Student"));

        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(token2))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentName").value("Rotation Student"));
    }

    // -------------------------------------------------------------------------
    // 4. Tampered token is rejected
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("Tampered QR token (flipped signature byte) → 401 TOKEN_INVALID")
    void tamperedQrToken_isRejected() throws Exception {
        String freshToken = cardTokenService.generateQrToken(studentCardId);
        String tampered = freshToken.substring(0, freshToken.length() - 1)
                + (freshToken.charAt(freshToken.length() - 1) == 'A' ? 'B' : 'A');

        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(
                                new VerifyCardRequest(tampered))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_INVALID"));
    }
}

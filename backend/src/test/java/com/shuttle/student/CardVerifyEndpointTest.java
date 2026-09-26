package com.shuttle.student;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.auth.dto.TokenResponse;
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
import org.springframework.transaction.annotation.Transactional;

import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("POST /api/cards/verify — Integration Tests")
class CardVerifyEndpointTest {

    @Autowired private MockMvc              mockMvc;
    @Autowired private ObjectMapper         objectMapper;
    @Autowired private AuthService          authService;
    @Autowired private CardTokenService     cardTokenService;
    @Autowired private JwtService           jwtService;
    @Autowired private UserRepository       userRepository;
    @Autowired private DriverRepository     driverRepository;
    @Autowired private PasswordEncoder      passwordEncoder;
    @Autowired private EntityManager        entityManager;

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    // Tokens shared across tests
    private String studentAccessToken;
    private String driverAccessToken;
    private String validQrToken;
    private String studentCardId;

    @BeforeEach
    @Transactional
    void setUp() {
        // ---------- student ----------
        if (!userRepository.existsByEmail("verify_student@test.com")) {
            authService.register(new RegisterRequest(
                    "Verify Student",
                    "verify_student@test.com",
                    "Password1!",
                    "VS001",
                    "Science",
                    2024,
                    null
            ));
        }
        User studentUser = userRepository.findByEmail("verify_student@test.com").orElseThrow();
        studentAccessToken = jwtService.generateAccessToken(studentUser);

        // Resolve card ID with JPQL to avoid lazy-loading the Student association
        studentCardId = entityManager
                .createQuery(
                        "SELECT v.cardId FROM VirtualBusCard v WHERE v.student.user.email = :email",
                        String.class)
                .setParameter("email", "verify_student@test.com")
                .getSingleResult();
        validQrToken = cardTokenService.generateQrToken(studentCardId);

        // ---------- driver ----------
        if (!userRepository.existsByEmail("verify_driver@test.com")) {
            User driverUser = new User();
            driverUser.setEmail("verify_driver@test.com");
            driverUser.setPasswordHash(passwordEncoder.encode("Password1!"));
            driverUser.setFullName("Test Driver");
            driverUser.setRole(Role.DRIVER);
            driverUser.setStatus(UserStatus.ACTIVE);
            userRepository.save(driverUser);

            Driver driver = new Driver();
            driver.setUser(driverUser);
            driver.setLicenseNumber("DL-TEST-001");
            driver.setStatus(DriverStatus.ACTIVE);
            driverRepository.save(driver);
        }
        User driverUser = userRepository.findByEmail("verify_driver@test.com").orElseThrow();
        driverAccessToken = jwtService.generateAccessToken(driverUser);
    }

    // -------------------------------------------------------------------------
    // Happy path
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("POST /api/cards/verify — valid token + DRIVER bearer → 200 with student name")
    void verify_validTokenDriverRole_returns200() throws Exception {
        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(validQrToken))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentName").value("Verify Student"))
                .andExpect(jsonPath("$.cardId", notNullValue()))
                .andExpect(jsonPath("$.cardStatus").value("ACTIVE"))
                .andExpect(jsonPath("$.monthlyPassStatus").value("NONE"));
    }

    // -------------------------------------------------------------------------
    // Expired token
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("POST /api/cards/verify — expired token → 401 TOKEN_EXPIRED")
    void verify_expiredToken_returns401() throws Exception {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        Instant past = Instant.now().minusSeconds(10);

        String expiredToken = Jwts.builder()
                .subject(studentCardId)
                .claim(CardTokenService.CLAIM_TYPE_KEY, CardTokenService.CLAIM_TYPE_VALUE)
                .issuedAt(Date.from(past.minusSeconds(60)))
                .expiration(Date.from(past))
                .signWith(key)
                .compact();

        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(expiredToken))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_EXPIRED"));
    }

    // -------------------------------------------------------------------------
    // Tampered token
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("POST /api/cards/verify — tampered token → 401 TOKEN_INVALID")
    void verify_tamperedToken_returns401() throws Exception {
        // Flip the last character of the valid token's signature
        String tampered = validQrToken.substring(0, validQrToken.length() - 1)
                + (validQrToken.charAt(validQrToken.length() - 1) == 'A' ? 'B' : 'A');

        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(tampered))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_INVALID"));
    }

    // -------------------------------------------------------------------------
    // Missing / wrong role
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("POST /api/cards/verify — no Authorization header → 401")
    void verify_noAuth_returns401() throws Exception {
        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(validQrToken))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("POST /api/cards/verify — STUDENT bearer token → 403")
    void verify_studentRole_returns403() throws Exception {
        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + studentAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(validQrToken))))
                .andExpect(status().isForbidden());
    }

    // -------------------------------------------------------------------------
    // Blank body validation
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("POST /api/cards/verify — blank token field → 400 VALIDATION_ERROR")
    void verify_blankToken_returns400() throws Exception {
        mockMvc.perform(post("/api/cards/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + driverAccessToken)
                        .content(objectMapper.writeValueAsString(new VerifyCardRequest(""))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }
}

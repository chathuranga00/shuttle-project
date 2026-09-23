package com.shuttle.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.auth.dto.LoginRequest;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.auth.dto.TokenResponse;
import com.shuttle.auth.dto.RefreshRequest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@DisplayName("Auth Integration Tests")
class AuthIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    // Shared state for token reuse across ordered tests
    private static String accessToken;
    private static String refreshToken;

    // -------------------------------------------------------------------------
    // Register
    // -------------------------------------------------------------------------

    @Test
    @Order(1)
    @DisplayName("POST /api/auth/register — successful registration returns 201 with tokens")
    void register_success() throws Exception {
        RegisterRequest request = new RegisterRequest(
                "Alice Student",
                "alice@test.com",
                "Password1!",
                "S2024001",
                "Engineering",
                2024,
                "+94771234567"
        );

        MvcResult result = mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accessToken", notNullValue()))
                .andExpect(jsonPath("$.refreshToken", notNullValue()))
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").value(900L))
                .andReturn();

        TokenResponse response = objectMapper.readValue(
                result.getResponse().getContentAsString(), TokenResponse.class);
        accessToken = response.accessToken();
        refreshToken = response.refreshToken();

        assertThat(accessToken).isNotBlank();
        assertThat(refreshToken).isNotBlank();
    }

    @Test
    @Order(2)
    @DisplayName("POST /api/auth/register — duplicate email returns 409 CONFLICT")
    void register_duplicateEmail_returns409() throws Exception {
        RegisterRequest request = new RegisterRequest(
                "Alice Duplicate",
                "alice@test.com",    // same email as test 1
                "Password1!",
                "S2024002",          // different student ID
                "Science",
                2024,
                null
        );

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_ALREADY_EXISTS"));
    }

    @Test
    @Order(3)
    @DisplayName("POST /api/auth/register — password too short returns 400 VALIDATION_ERROR")
    void register_shortPassword_returns400() throws Exception {
        RegisterRequest request = new RegisterRequest(
                "Bob Student",
                "bob@test.com",
                "short",             // less than 8 chars
                "S2024003",
                "Arts",
                2023,
                null
        );

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("8 characters")));
    }

    // -------------------------------------------------------------------------
    // Login
    // -------------------------------------------------------------------------

    @Test
    @Order(4)
    @DisplayName("POST /api/auth/login — correct credentials return 200 with tokens")
    void login_success() throws Exception {
        LoginRequest request = new LoginRequest("alice@test.com", "Password1!");

        MvcResult result = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken", notNullValue()))
                .andExpect(jsonPath("$.refreshToken", notNullValue()))
                .andReturn();

        // Update shared token for downstream tests
        TokenResponse response = objectMapper.readValue(
                result.getResponse().getContentAsString(), TokenResponse.class);
        accessToken = response.accessToken();
        refreshToken = response.refreshToken();
    }

    @Test
    @Order(5)
    @DisplayName("POST /api/auth/login — wrong password returns 401 INVALID_CREDENTIALS")
    void login_wrongPassword_returns401() throws Exception {
        LoginRequest request = new LoginRequest("alice@test.com", "WrongPassword!");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    @Order(6)
    @DisplayName("POST /api/auth/login — unknown email returns 401 INVALID_CREDENTIALS")
    void login_unknownEmail_returns401() throws Exception {
        LoginRequest request = new LoginRequest("nobody@test.com", "Password1!");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    // -------------------------------------------------------------------------
    // Token refresh
    // -------------------------------------------------------------------------

    @Test
    @Order(7)
    @DisplayName("POST /api/auth/refresh — valid refresh token returns new access token")
    void refresh_success() throws Exception {
        assertThat(refreshToken).as("refreshToken from login must be set").isNotNull();

        RefreshRequest request = new RefreshRequest(refreshToken);

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken", notNullValue()))
                .andExpect(jsonPath("$.refreshToken", notNullValue()));
    }

    @Test
    @Order(8)
    @DisplayName("POST /api/auth/refresh — already-used refresh token returns 401 (rotation)")
    void refresh_reuseRevoked_returns401() throws Exception {
        // The token used in test 7 was rotated (revoked), so reusing it must fail
        assertThat(refreshToken).as("refreshToken must be set").isNotNull();

        RefreshRequest request = new RefreshRequest(refreshToken);

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("REFRESH_TOKEN_REVOKED"));
    }

    // -------------------------------------------------------------------------
    // Authorization
    // -------------------------------------------------------------------------

    @Test
    @Order(9)
    @DisplayName("GET /api/students/me — no token returns 401")
    void studentMe_noToken_returns401() throws Exception {
        mockMvc.perform(get("/api/students/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @Order(10)
    @DisplayName("GET /api/students/me — valid student token returns 200")
    void studentMe_validToken_returns200() throws Exception {
        assertThat(accessToken).as("accessToken must be set").isNotNull();

        mockMvc.perform(get("/api/students/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("alice@test.com"))
                .andExpect(jsonPath("$.studentId").value("S2024001"));
    }

    @Test
    @Order(11)
    @DisplayName("GET /api/admin/** — student token returns 403 ACCESS_DENIED")
    void adminEndpoint_withStudentToken_returns403() throws Exception {
        assertThat(accessToken).as("accessToken must be set").isNotNull();

        mockMvc.perform(get("/api/admin/users")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @Order(12)
    @DisplayName("GET /api/admin/** — no token returns 401")
    void adminEndpoint_noToken_returns401() throws Exception {
        mockMvc.perform(get("/api/admin/users"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @Order(13)
    @DisplayName("GET /api/students/me/card — valid student token returns card summary with qrToken")
    void studentCard_validToken_returns200() throws Exception {
        assertThat(accessToken).as("accessToken must be set").isNotNull();

        mockMvc.perform(get("/api/students/me/card")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cardId", notNullValue()))
                .andExpect(jsonPath("$.cardStatus").value("ACTIVE"))
                .andExpect(jsonPath("$.wallet.balance").value(0))
                .andExpect(jsonPath("$.wallet.status").value("ACTIVE"))
                // qrToken must be a 3-part JWT (header.payload.signature)
                .andExpect(jsonPath("$.qrToken", notNullValue()))
                .andExpect(jsonPath("$.qrToken",
                        org.hamcrest.Matchers.matchesPattern("^[\\w-]+\\.[\\w-]+\\.[\\w-]+$")));
    }

    @Test
    @Order(14)
    @DisplayName("POST /api/auth/login — missing email field returns 400 VALIDATION_ERROR")
    void login_missingEmail_returns400() throws Exception {
        String body = """
                { "password": "Password1!" }
                """;

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }
}

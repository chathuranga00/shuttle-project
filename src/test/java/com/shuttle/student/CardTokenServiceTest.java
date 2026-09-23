package com.shuttle.student;

import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.domain.entity.VirtualBusCard;
import com.shuttle.domain.enums.CardStatus;
import com.shuttle.domain.repository.VirtualBusCardRepository;
import com.shuttle.exception.ApiException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
@DisplayName("CardTokenService Unit Tests")
class CardTokenServiceTest {

    @Autowired
    private CardTokenService cardTokenService;

    @Autowired
    private AuthService authService;

    @Autowired
    private VirtualBusCardRepository virtualBusCardRepository;

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    // Student registered once per test (transaction rolled back after each)
    private String cardId;

    @BeforeEach
    void setUp() {
        // Register a fresh student — AuthService creates User + Student + Wallet + VirtualBusCard
        authService.register(new RegisterRequest(
                "Test Student",
                "cardtest@example.com",
                "Password1!",
                "CARD001",
                "Engineering",
                2024,
                null
        ));

        cardId = virtualBusCardRepository.findAll().stream()
                .filter(c -> c.getStudent().getUser().getEmail().equals("cardtest@example.com"))
                .findFirst()
                .map(VirtualBusCard::getCardId)
                .orElseThrow(() -> new IllegalStateException("Card not created during registration"));
    }

    // -------------------------------------------------------------------------
    // generateQrToken
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("generateQrToken — produces a 3-part JWT with correct claims")
    void generateQrToken_hasCorrectStructure() {
        String token = cardTokenService.generateQrToken(cardId);

        // Must be a compact JWT (header.payload.signature)
        String[] parts = token.split("\\.");
        assertThat(parts).hasSize(3);

        // Verify type claim via verification path
        CardVerificationResult result = cardTokenService.verifyCardToken(token);
        assertThat(result.cardId()).isEqualTo(cardId);
        assertThat(result.cardStatus()).isEqualTo("ACTIVE");
    }

    // -------------------------------------------------------------------------
    // verifyCardToken — happy path
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("verifyCardToken — valid token returns correct CardVerificationResult")
    void verifyCardToken_validToken_returnsResult() {
        String token = cardTokenService.generateQrToken(cardId);

        CardVerificationResult result = cardTokenService.verifyCardToken(token);

        assertThat(result.studentName()).isEqualTo("Test Student");
        assertThat(result.cardId()).isEqualTo(cardId);
        assertThat(result.cardStatus()).isEqualTo("ACTIVE");
        assertThat(result.monthlyPassStatus()).isEqualTo("NONE");
    }

    // -------------------------------------------------------------------------
    // verifyCardToken — expired token
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("verifyCardToken — expired token throws ApiException TOKEN_EXPIRED")
    void verifyCardToken_expiredToken_throwsTokenExpired() {
        // Build an already-expired token directly with the test secret
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        Instant past = Instant.now().minusSeconds(10);
        String expiredToken = Jwts.builder()
                .subject(cardId)
                .claim(CardTokenService.CLAIM_TYPE_KEY, CardTokenService.CLAIM_TYPE_VALUE)
                .issuedAt(Date.from(past.minusSeconds(60)))
                .expiration(Date.from(past))          // already expired
                .signWith(key)
                .compact();

        assertThatThrownBy(() -> cardTokenService.verifyCardToken(expiredToken))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.getCode()).isEqualTo("TOKEN_EXPIRED");
                    assertThat(apiEx.getStatus().value()).isEqualTo(401);
                });
    }

    // -------------------------------------------------------------------------
    // verifyCardToken — tampered token
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("verifyCardToken — tampered signature throws ApiException TOKEN_INVALID")
    void verifyCardToken_tamperedSignature_throwsTokenInvalid() {
        String token = cardTokenService.generateQrToken(cardId);

        // Flip the last character of the signature segment
        int lastDot = token.lastIndexOf('.');
        String tampered = token.substring(0, token.length() - 1)
                + (token.charAt(token.length() - 1) == 'A' ? 'B' : 'A');

        assertThatThrownBy(() -> cardTokenService.verifyCardToken(tampered))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.getCode()).isEqualTo("TOKEN_INVALID");
                    assertThat(apiEx.getStatus().value()).isEqualTo(401);
                });
    }

    // -------------------------------------------------------------------------
    // verifyCardToken — access-token replay rejected
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("verifyCardToken — token missing QR_BOARDING type claim is rejected")
    void verifyCardToken_wrongTypeClaim_throwsTokenInvalid() {
        // Build a token that looks structurally valid but has no type claim
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        Instant now = Instant.now();
        String noTypeToken = Jwts.builder()
                .subject(cardId)
                // Deliberately omit CLAIM_TYPE_KEY
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(60)))
                .signWith(key)
                .compact();

        assertThatThrownBy(() -> cardTokenService.verifyCardToken(noTypeToken))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.getCode()).isEqualTo("TOKEN_INVALID");
                });
    }

    // -------------------------------------------------------------------------
    // verifyCardToken — suspended card
    // -------------------------------------------------------------------------

    @Test
    @DisplayName("verifyCardToken — non-ACTIVE card (BLOCKED) throws ApiException CARD_SUSPENDED")
    void verifyCardToken_suspendedCard_throwsCardSuspended() {
        // Block the card (CardStatus has ACTIVE, INACTIVE, BLOCKED, EXPIRED — no SUSPENDED)
        VirtualBusCard card = virtualBusCardRepository.findAll().stream()
                .filter(c -> c.getCardId().equals(cardId))
                .findFirst()
                .orElseThrow();
        card.setStatus(CardStatus.BLOCKED);
        virtualBusCardRepository.save(card);
        virtualBusCardRepository.flush();

        // Generate token AFTER suspending so we can prove the DB check fires
        String token = cardTokenService.generateQrToken(cardId);

        assertThatThrownBy(() -> cardTokenService.verifyCardToken(token))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.getCode()).isEqualTo("CARD_SUSPENDED");
                    assertThat(apiEx.getStatus().value()).isEqualTo(401);
                });
    }
}

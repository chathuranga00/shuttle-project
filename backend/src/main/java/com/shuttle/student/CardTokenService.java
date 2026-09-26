package com.shuttle.student;

import com.shuttle.config.JwtProperties;
import com.shuttle.domain.entity.VirtualBusCard;
import com.shuttle.domain.enums.CardStatus;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.VirtualBusCardRepository;
import com.shuttle.exception.ApiException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Generates and verifies short-lived, signed QR tokens for virtual bus cards.
 *
 * <p>Token contents (JWT claims):
 * <ul>
 *   <li>{@code sub}  — cardId (not a user identifier — safe to embed in QR)</li>
 *   <li>{@code type} — {@value #CLAIM_TYPE_VALUE} (distinguishes QR tokens from access tokens)</li>
 *   <li>{@code iat}  — issued-at</li>
 *   <li>{@code exp}  — issued-at + {@value #QR_TTL_SECONDS} seconds</li>
 * </ul>
 * No user name, email, role, or other PII is included.
 */
@Service
@RequiredArgsConstructor
public class CardTokenService {

    /** Claim key used to tag the token type — prevents access-token replay. */
    static final String CLAIM_TYPE_KEY   = "type";
    /** Expected value of the {@code type} claim for valid QR tokens. */
    static final String CLAIM_TYPE_VALUE = "QR_BOARDING";
    /** QR token lifetime in seconds. */
    static final long   QR_TTL_SECONDS   = 60L;

    private final JwtProperties            jwtProperties;
    private final VirtualBusCardRepository virtualBusCardRepository;
    private final MonthlyPassRepository    monthlyPassRepository;

    private SecretKey signingKey;

    @PostConstruct
    void init() {
        signingKey = Keys.hmacShaKeyFor(
                jwtProperties.secret().getBytes(StandardCharsets.UTF_8));
    }

    // -------------------------------------------------------------------------
    // Generate
    // -------------------------------------------------------------------------

    /**
     * Generates a signed, short-lived QR token for the given card ID.
     * The token does NOT contain any PII.
     *
     * @param cardId the card's business identifier (e.g. {@code UBC-S001-1234})
     * @return a compact JWT string suitable for encoding in a QR code
     */
    public String generateQrToken(String cardId) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(cardId)
                .claim(CLAIM_TYPE_KEY, CLAIM_TYPE_VALUE)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(QR_TTL_SECONDS)))
                .signWith(signingKey)
                .compact();
    }

    // -------------------------------------------------------------------------
    // Verify
    // -------------------------------------------------------------------------

    /**
     * Validates a QR token and returns enriched card/student data.
     *
     * <p>Checks (in order):
     * <ol>
     *   <li>JWT signature and expiry</li>
     *   <li>Token {@code type} claim equals {@value #CLAIM_TYPE_VALUE}</li>
     *   <li>Card exists and has status {@code ACTIVE}</li>
     *   <li>Owning student's user account has status {@code ACTIVE}</li>
     * </ol>
     *
     * @param token the compact JWT string scanned from the QR code
     * @return a {@link CardVerificationResult} with student name, card ID, statuses
     * @throws ApiException with appropriate error code on any failure
     */
    @Transactional(readOnly = true)
    public CardVerificationResult verifyCardToken(String token) {
        // 1. Parse and verify signature / expiry
        Claims claims = parseClaims(token);

        // 2. Guard against access-token replay attacks
        String tokenType = claims.get(CLAIM_TYPE_KEY, String.class);
        if (!CLAIM_TYPE_VALUE.equals(tokenType)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALID", "Token is not a valid QR boarding token.");
        }

        String cardId = claims.getSubject();

        // 3. Load the card
        VirtualBusCard card = virtualBusCardRepository.findByCardId(cardId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED,
                        "CARD_NOT_FOUND", "Card not found."));

        if (card.getStatus() != CardStatus.ACTIVE) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "CARD_SUSPENDED", "This bus card is not active.");
        }

        // 4. Check student / user status
        if (card.getStudent().getUser().getStatus() != UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "STUDENT_SUSPENDED", "The student account is not active.");
        }

        // 5. Resolve monthly-pass status
        boolean hasActivePass = !monthlyPassRepository
                .findByStudentIdAndStatus(card.getStudent().getId(), PassStatus.ACTIVE)
                .isEmpty();
        String passStatus = hasActivePass ? "ACTIVE" : "NONE";

        return new CardVerificationResult(
                card.getStudent().getUser().getFullName(),
                card.getCardId(),
                card.getStatus().name(),
                passStatus
        );
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Claims parseClaims(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(signingKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (ExpiredJwtException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "TOKEN_EXPIRED", "QR token has expired. Please refresh and try again.");
        } catch (JwtException ex) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALID", "QR token signature is invalid.");
        }
    }
}

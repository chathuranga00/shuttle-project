package com.shuttle.payment.gateway;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

/**
 * Mock payment gateway for development and testing.
 *
 * <p>Behaviour:
 * <ul>
 *   <li>{@link #createCheckout} returns a URL pointing to
 *       {@code /api/payment/mock-callback?paymentId=X&status=success}.
 *       The mock-callback endpoint auto-approves the payment and fires the webhook
 *       pipeline immediately — no actual redirect or browser needed in tests.</li>
 *   <li>{@link #verifyPayment} validates an HMAC-SHA256 hash computed with a
 *       hard-coded test secret so the webhook pipeline is exercised properly
 *       (no real credential required).</li>
 *   <li>{@link #pollStatus} returns SUCCESS for any orderId to allow the Flutter
 *       polling flow to complete.</li>
 * </ul>
 *
 * <p>Activated when {@code app.payment.gateway=mock} (the default in dev/test profiles).
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "app.payment.gateway", havingValue = "mock", matchIfMissing = true)
public class MockPaymentGateway implements PaymentGateway {

    /** Hard-coded test secret — never used in production. */
    private static final String MOCK_SECRET = "mock-gateway-test-secret-not-for-prod";
    private static final String HASH_PARAM  = "mock_hash";

    @Override
    public String createCheckout(String orderId, BigDecimal amount,
                                  String description, String callbackUrl, String returnUrl) {
        log.info("[MockGateway] createCheckout orderId={} amount={}", orderId, amount);
        // Return a local mock-callback URL that auto-approves via the webhook pipeline
        return "/api/payment/mock-callback?paymentId=" + orderId
                + "&status=success"
                + "&" + HASH_PARAM + "=" + computeHash(orderId, "success");
    }

    @Override
    public boolean verifyPayment(Map<String, String> params) {
        String orderId = params.get("paymentId");
        String status  = params.getOrDefault("status", "");
        String givenHash = params.getOrDefault(HASH_PARAM, "");
        String expected  = computeHash(orderId, status);

        boolean valid = expected.equals(givenHash) && "success".equalsIgnoreCase(status);
        log.info("[MockGateway] verifyPayment orderId={} valid={}", orderId, valid);
        return valid;
    }

    @Override
    public GatewayPaymentStatus pollStatus(String orderId) {
        // Mock always reports success — in real gateways this calls the gateway's status API
        log.info("[MockGateway] pollStatus orderId={} → SUCCESS", orderId);
        return GatewayPaymentStatus.SUCCESS;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String computeHash(String orderId, String status) {
        try {
            String input = orderId + "|" + status + "|" + MOCK_SECRET;
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    md.digest(input.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}

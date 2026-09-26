package com.shuttle.payment.gateway;

import java.math.BigDecimal;
import java.util.Map;

/**
 * Abstraction over a payment gateway.
 *
 * <p>Each concrete implementation must:
 * <ul>
 *   <li>Create a checkout session that redirects the user to the gateway UI.</li>
 *   <li>Verify an incoming webhook notification server-side (signature/hash check)
 *       before crediting any account — the Flutter app must never be trusted to
 *       declare a payment successful.</li>
 *   <li>Poll for the current payment status when needed (e.g., after the app
 *       returns from the redirect flow).</li>
 * </ul>
 */
public interface PaymentGateway {

    /**
     * Initiates a payment and returns a checkout URL the user is redirected to.
     *
     * @param orderId      internal payment ID (used as the gateway order reference)
     * @param amount       payment amount in LKR
     * @param description  human-readable description shown on the gateway page
     * @param callbackUrl  backend webhook/callback URL the gateway POSTs to on completion
     * @param returnUrl    deep-link or redirect URL the gateway sends the user back to
     * @return checkout URL to open in WebView or browser
     */
    String createCheckout(String orderId, BigDecimal amount,
                          String description, String callbackUrl, String returnUrl);

    /**
     * Verifies an incoming webhook/callback from the gateway.
     * Implementations MUST check the gateway's signature/hash before returning
     * {@code true}. Never rely on the Flutter app to confirm payment.
     *
     * @param params raw POST parameters from the gateway webhook
     * @return true if the payment is genuine and successful
     */
    boolean verifyPayment(Map<String, String> params);

    /**
     * Polls the gateway for the current status of a payment by its order ID.
     * Used when the app returns from the redirect flow and we need a server-side
     * confirmation rather than trusting the redirect URL parameters.
     *
     * @param orderId internal payment ID
     * @return {@link GatewayPaymentStatus} describing the current state
     */
    GatewayPaymentStatus pollStatus(String orderId);

    // ── Shared result type ────────────────────────────────────────────────────

    enum GatewayPaymentStatus { PENDING, SUCCESS, FAILED, CANCELLED }
}

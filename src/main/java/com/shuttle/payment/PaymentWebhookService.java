package com.shuttle.payment;

import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.enums.PaymentStatus;
import com.shuttle.domain.enums.PaymentType;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.payment.gateway.PaymentGateway;
import com.shuttle.payment.gateway.PaymentGateway.GatewayPaymentStatus;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.notification.NotificationService;
import com.shuttle.wallet.WalletService;
import jakarta.persistence.EntityNotFoundException;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentWebhookService {

    private final PaymentRepository     paymentRepository;
    private final MonthlyPassRepository monthlyPassRepository;
    private final WalletService         walletService;
    private final PaymentGateway        paymentGateway;
    private final NotificationService   notificationService;

    /**
     * Processes a gateway webhook or mock-callback.
     *
     * @param params raw POST/GET parameters from the gateway
     * @return "OK" on success; throws {@link ApiException} on failure
     */
    @Transactional
    public String handleWebhook(Map<String, String> params) {
        // 1. Verify gateway signature — never trust unverified webhook calls
        if (!paymentGateway.verifyPayment(params)) {
            log.warn("Webhook signature verification failed: {}", params);
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "WEBHOOK_INVALID", "Payment signature verification failed.");
        }

        // 2. Locate the payment by internal order ID
        String orderId = params.get("paymentId");
        Payment payment = paymentRepository.findById(Long.parseLong(orderId))
                .orElseThrow(() -> new EntityNotFoundException(
                        "Payment " + orderId + " not found."));

        // 3. Idempotency: gateway_transaction_id dedup
        String gatewayTxId = params.getOrDefault("gatewayTxId", "mock-" + orderId);
        Optional<Payment> existing = paymentRepository.findByGatewayTransactionId(gatewayTxId);
        if (existing.isPresent()) {
            log.info("Duplicate webhook for gatewayTxId={} — already processed.", gatewayTxId);
            return "OK (duplicate ignored)";
        }

        // 4. Guard: only process PENDING payments
        if (payment.getStatus() != PaymentStatus.PENDING) {
            log.warn("Webhook received for non-PENDING payment id={} status={}",
                    payment.getId(), payment.getStatus());
            return "OK (already " + payment.getStatus() + ")";
        }

        // 5. Mark gateway transaction ID to prevent future duplicates
        payment.setGatewayTransactionId(gatewayTxId);
        paymentRepository.save(payment);
        paymentRepository.flush();

        // 6. Dispatch to the correct fulfillment path
        if (payment.getType() == PaymentType.WALLET_TOPUP) {
            walletService.creditWallet(payment);
            log.info("Wallet credited for payment id={} amount={}", payment.getId(), payment.getAmount());

        } else if (payment.getType() == PaymentType.MONTHLY_PASS) {
            activatePass(payment);
            log.info("Monthly pass activated for payment id={}", payment.getId());

        } else {
            log.warn("Unhandled payment type {} for id={}", payment.getType(), payment.getId());
            payment.setStatus(PaymentStatus.FAILED);
            paymentRepository.save(payment);
        }

        return "OK";
    }

    /**
     * Server-side status poll — called by the Flutter app after returning from checkout.
     * Returns the current payment status WITHOUT changing any state.
     * The app must not act on a SUCCESS response here alone; it should rely on the
     * webhook having already fired.
     */
    @Transactional(readOnly = true)
    public PaymentStatusResponse pollPaymentStatus(Long paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new EntityNotFoundException(
                        "Payment " + paymentId + " not found."));

        // Optionally cross-check with the gateway (used when webhook hasn't fired yet)
        if (payment.getStatus() == PaymentStatus.PENDING) {
            GatewayPaymentStatus gw = paymentGateway.pollStatus(
                    String.valueOf(payment.getId()));
            if (gw == GatewayPaymentStatus.SUCCESS) {
                // Webhook should have fired, but hasn't yet — return PENDING to trigger retry
                log.info("pollStatus: gateway says SUCCESS but webhook not yet received for id={}",
                        paymentId);
            }
        }

        return new PaymentStatusResponse(
                payment.getId(),
                payment.getStatus().name(),
                payment.getAmount(),
                payment.getType().name());
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private void activatePass(Payment payment) {
        if (payment.getMonthlyPass() == null) {
            log.error("MONTHLY_PASS payment {} has no pass linked.", payment.getId());
            payment.setStatus(PaymentStatus.FAILED);
            return;
        }
        MonthlyPass pass = payment.getMonthlyPass();
        pass.setStatus(PassStatus.ACTIVE);
        monthlyPassRepository.save(pass);
        payment.setStatus(PaymentStatus.SUCCESS);
        paymentRepository.save(payment);

        if (payment.getStudent() != null && payment.getStudent().getUser() != null) {
            notificationService.createNotification(
                    payment.getStudent().getUser(),
                    "Monthly Pass Activated",
                    "Your monthly pass (#" + pass.getId() + ") is now active until " + pass.getValidTo() + ".",
                    NotificationType.PASS
            );
        }
    }
}

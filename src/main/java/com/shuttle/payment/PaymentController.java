package com.shuttle.payment;

import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.wallet.dto.PaymentHistoryItem;
import com.shuttle.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.persistence.EntityNotFoundException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/payment")
@RequiredArgsConstructor
@Tag(name = "Payment", description = "Payment webhook and history")
public class PaymentController {

    private final PaymentWebhookService webhookService;
    private final PaymentRepository     paymentRepository;
    private final StudentRepository     studentRepository;

    /**
     * Gateway webhook endpoint — called by the payment gateway server-to-server.
     * No JWT required. Signature is verified inside the service.
     */
    @PostMapping("/webhook")
    @Operation(summary = "Payment gateway webhook (gateway → server, no auth required)")
    public String webhook(@RequestParam Map<String, String> params) {
        return webhookService.handleWebhook(params);
    }

    /**
     * Mock-callback endpoint — simulates a successful gateway redirect in dev/test.
     * Calls the webhook pipeline directly with mock parameters.
     */
    @GetMapping("/mock-callback")
    @Operation(summary = "Mock gateway callback (dev/test only)")
    public String mockCallback(@RequestParam Map<String, String> params) {
        return webhookService.handleWebhook(params);
    }

    /**
     * Flutter-callable poll endpoint — checks the server-side payment status after
     * the app returns from checkout. The app must NOT consider a payment successful
     * based solely on this response; it is just a status read.
     */
    @GetMapping("/status/{paymentId}")
    @Operation(summary = "Poll payment status (authenticated student)")
    @SecurityRequirement(name = "bearerAuth")
    public PaymentStatusResponse getStatus(@PathVariable Long paymentId) {
        return webhookService.pollPaymentStatus(paymentId);
    }

    /** Payment history for the authenticated student. */
    @GetMapping("/history")
    @Operation(summary = "Get payment history for the authenticated student")
    @SecurityRequirement(name = "bearerAuth")
    public List<PaymentHistoryItem> getHistory(Authentication auth) {
        UserPrincipal principal = (UserPrincipal) auth.getPrincipal();
        Long studentId = studentRepository.findByUserId(principal.getId())
                .map(s -> s.getId())
                .orElse(null);
        if (studentId == null) return List.of();

        return paymentRepository.findByStudentIdOrderByCreatedAtDesc(studentId)
                .stream()
                .map(p -> new PaymentHistoryItem(
                        p.getId(), p.getType().name(),
                        p.getAmount(), p.getStatus().name(),
                        p.getDescription(), p.getCreatedAt()))
                .collect(Collectors.toList());
    }
}

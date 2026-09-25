package com.shuttle.wallet;

import com.shuttle.config.PaymentProperties;
import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.Wallet;
import com.shuttle.domain.entity.WalletTransaction;
import com.shuttle.domain.enums.PaymentMethod;
import com.shuttle.domain.enums.PaymentStatus;
import com.shuttle.domain.enums.PaymentType;
import com.shuttle.domain.enums.TransactionType;
import com.shuttle.domain.enums.WalletStatus;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.WalletRepository;
import com.shuttle.domain.repository.WalletTransactionRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.payment.gateway.PaymentGateway;
import com.shuttle.security.UserPrincipal;
import com.shuttle.wallet.dto.TopUpRequest;
import com.shuttle.wallet.dto.TopUpResponse;
import com.shuttle.wallet.dto.TransactionItem;
import com.shuttle.wallet.dto.WalletResponse;
import jakarta.persistence.EntityNotFoundException;
import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.notification.NotificationService;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class WalletService {

    static final String MSG_INSUFFICIENT_BALANCE = "Insufficient wallet balance.";
    static final String MSG_WALLET_FROZEN        = "Your wallet is not active.";

    private final WalletRepository            walletRepository;
    private final WalletTransactionRepository txRepository;
    private final PaymentRepository           paymentRepository;
    private final StudentRepository           studentRepository;
    private final PaymentGateway              paymentGateway;
    private final PaymentProperties           paymentProperties;
    private final NotificationService         notificationService;

    // ── GET wallet ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public WalletResponse getWallet(Authentication auth) {
        Wallet wallet = loadWallet(resolve(auth).getId());
        return new WalletResponse(
                wallet.getId(),
                wallet.getBalance(),
                wallet.getStatus().name());
    }

    // ── GET transactions ──────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<TransactionItem> getTransactions(Authentication auth) {
        Wallet wallet = loadWallet(resolve(auth).getId());
        return txRepository.findByWalletIdOrderByCreatedAtDesc(wallet.getId())
                .stream()
                .map(t -> new TransactionItem(
                        t.getId(), t.getType().name(),
                        t.getAmount(), t.getBalanceAfter(),
                        t.getDescription(), t.getCreatedAt()))
                .collect(Collectors.toList());
    }

    // ── POST top-up ───────────────────────────────────────────────────────────

    /**
     * Creates a PENDING top-up payment and returns the gateway checkout URL.
     * The wallet is NOT credited here — that happens only after the webhook
     * confirms the payment server-side.
     */
    @Transactional
    public TopUpResponse initiateTopUp(TopUpRequest req, Authentication auth) {
        Student student = resolve(auth);
        Wallet  wallet  = loadWallet(student.getId());

        if (wallet.getStatus() != WalletStatus.ACTIVE) {
            throw new ApiException(HttpStatus.FORBIDDEN, "WALLET_FROZEN", MSG_WALLET_FROZEN);
        }
        if (req.amount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_AMOUNT",
                    "Top-up amount must be greater than zero.");
        }

        // Create the PENDING payment record
        Payment payment = new Payment();
        payment.setStudent(student);
        payment.setAmount(req.amount());
        payment.setType(PaymentType.WALLET_TOPUP);
        payment.setMethod(PaymentMethod.ONLINE);
        payment.setStatus(PaymentStatus.PENDING);
        payment.setDescription("Wallet top-up: LKR " + req.amount());
        paymentRepository.save(payment);
        paymentRepository.flush();   // ensure ID is set before calling gateway

        // Build callback URLs
        String callbackUrl = paymentProperties.baseUrl() + "/api/payment/webhook";
        String returnUrl   = paymentProperties.baseUrl()
                + "/api/payment/return?paymentId=" + payment.getId();

        // Ask the gateway for a checkout URL (no credentials leave the server)
        String checkoutUrl = paymentGateway.createCheckout(
                String.valueOf(payment.getId()),
                req.amount(),
                payment.getDescription(),
                callbackUrl,
                returnUrl);

        payment.setCheckoutUrl(checkoutUrl);
        paymentRepository.save(payment);

        return new TopUpResponse(payment.getId(), checkoutUrl,
                PaymentStatus.PENDING.name(), req.amount());
    }

    // ── Credit wallet (called by webhook handler) ─────────────────────────────

    /**
     * Credits the wallet after a verified successful payment.
     * Called inside the webhook transaction — never call this without verifying
     * the gateway signature first.
     */
    @Transactional
    public void creditWallet(Payment payment) {
        Wallet wallet = walletRepository.findByStudentId(payment.getStudent().getId())
                .orElseThrow(() -> new EntityNotFoundException("Wallet not found."));

        BigDecimal newBalance = wallet.getBalance().add(payment.getAmount());
        wallet.setBalance(newBalance);
        walletRepository.save(wallet);

        WalletTransaction tx = new WalletTransaction();
        tx.setWallet(wallet);
        tx.setAmount(payment.getAmount());
        tx.setType(TransactionType.CREDIT);
        tx.setDescription("Wallet top-up via payment #" + payment.getId());
        tx.setReferenceType("PAYMENT");
        tx.setReferenceId(payment.getId());
        tx.setBalanceAfter(newBalance);
        txRepository.save(tx);

        payment.setWalletTransaction(tx);
        payment.setStatus(PaymentStatus.SUCCESS);
        paymentRepository.save(payment);

        if (payment.getStudent() != null && payment.getStudent().getUser() != null) {
            notificationService.createNotification(
                    payment.getStudent().getUser(),
                    "Payment Successful",
                    "Your wallet was credited with LKR " + payment.getAmount() + ". Current balance: LKR " + newBalance + ".",
                    NotificationType.PAYMENT
            );
        }
    }

    // ── Deduct fare (called by BoardingWriter in the same DB transaction) ─────

    /**
     * Deducts the fare from the wallet atomically using a pessimistic write lock.
     * Throws {@link ApiException} if the balance is insufficient.
     * {@code boardingRecordId} may be {@code null} when called before the boarding
     * record is persisted — the caller is responsible for back-filling it.
     * Returns the created {@link WalletTransaction}.
     */
    @Transactional
    public WalletTransaction deductFare(Long studentId, BigDecimal fare,
                                         Long boardingRecordId) {
        Wallet wallet = walletRepository.findByStudentIdWithLock(studentId)
                .orElseThrow(() -> new EntityNotFoundException("Wallet not found."));

        if (wallet.getStatus() != WalletStatus.ACTIVE) {
            throw new ApiException(HttpStatus.FORBIDDEN, "WALLET_FROZEN", MSG_WALLET_FROZEN);
        }
        if (wallet.getBalance().compareTo(fare) < 0) {
            throw new ApiException(HttpStatus.PAYMENT_REQUIRED,
                    "INSUFFICIENT_BALANCE", MSG_INSUFFICIENT_BALANCE);
        }

        BigDecimal newBalance = wallet.getBalance().subtract(fare);
        wallet.setBalance(newBalance);
        walletRepository.save(wallet);

        WalletTransaction tx = new WalletTransaction();
        tx.setWallet(wallet);
        tx.setAmount(fare);
        tx.setType(TransactionType.DEBIT);
        tx.setDescription("Boarding fare deduction");
        tx.setReferenceType("BOARDING");
        tx.setReferenceId(boardingRecordId);
        tx.setBalanceAfter(newBalance);
        return txRepository.save(tx);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private Student resolve(Authentication auth) {
        UserPrincipal principal = (UserPrincipal) auth.getPrincipal();
        return studentRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new EntityNotFoundException("Student not found."));
    }

    private Wallet loadWallet(Long studentId) {
        return walletRepository.findByStudentId(studentId)
                .orElseThrow(() -> new EntityNotFoundException("Wallet not found."));
    }
}

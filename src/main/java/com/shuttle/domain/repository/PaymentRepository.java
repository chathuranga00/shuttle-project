package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.enums.PaymentStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    List<Payment> findByStudentId(Long studentId);

    List<Payment> findByStudentIdAndStatus(Long studentId, PaymentStatus status);

    List<Payment> findByStudentIdOrderByCreatedAtDesc(Long studentId);

    /** Idempotency check — if this gateway transaction was already processed, return it. */
    Optional<Payment> findByGatewayTransactionId(String gatewayTransactionId);
}

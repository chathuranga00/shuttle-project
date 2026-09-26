package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.enums.PaymentStatus;
import java.util.List;
import java.util.Optional;
import java.math.BigDecimal;
import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaymentRepository extends JpaRepository<Payment, Long>, JpaSpecificationExecutor<Payment> {

    List<Payment> findByStudentId(Long studentId);

    List<Payment> findByStudentIdAndStatus(Long studentId, PaymentStatus status);

    List<Payment> findByStudentIdOrderByCreatedAtDesc(Long studentId);

    /** Idempotency check — if this gateway transaction was already processed, return it. */
    Optional<Payment> findByGatewayTransactionId(String gatewayTransactionId);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCESS' AND p.createdAt >= :from AND p.createdAt <= :to")
    BigDecimal sumRevenueBetween(@Param("from") Instant from, @Param("to") Instant to);

    List<Payment> findByCreatedAtBetween(Instant from, Instant to);
}

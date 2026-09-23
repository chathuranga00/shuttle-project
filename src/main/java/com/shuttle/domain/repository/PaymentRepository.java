package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.enums.PaymentStatus;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    List<Payment> findByStudentId(Long studentId);
    List<Payment> findByStudentIdAndStatus(Long studentId, PaymentStatus status);
}

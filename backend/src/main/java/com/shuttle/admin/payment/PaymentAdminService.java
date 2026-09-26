package com.shuttle.admin.payment;

import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.enums.PaymentStatus;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.exception.ApiException;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PaymentAdminService {

    private final PaymentRepository paymentRepository;

    @Transactional(readOnly = true)
    public Page<PaymentAdminResponse> listPayments(
            PaymentStatus status,
            LocalDate from,
            LocalDate to,
            String search,
            Pageable pageable
    ) {
        Specification<Payment> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }

            if (from != null) {
                Instant fromInstant = from.atStartOfDay(ZoneOffset.UTC).toInstant();
                predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"), fromInstant));
            }

            if (to != null) {
                Instant toInstant = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
                predicates.add(cb.lessThan(root.get("createdAt"), toInstant));
            }

            if (search != null && !search.trim().isEmpty()) {
                String pattern = "%" + search.trim().toLowerCase() + "%";
                Predicate studentName = cb.like(cb.lower(root.get("student").get("user").get("fullName")), pattern);
                Predicate studentId = cb.like(cb.lower(root.get("student").get("studentId")), pattern);
                Predicate providerRef = cb.like(cb.lower(root.get("providerReference")), pattern);
                Predicate desc = cb.like(cb.lower(root.get("description")), pattern);
                predicates.add(cb.or(studentName, studentId, providerRef, desc));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };

        return paymentRepository.findAll(spec, pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public PaymentAdminResponse getById(Long id) {
        Payment p = paymentRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "PAYMENT_NOT_FOUND", "Payment not found with ID: " + id));
        return toResponse(p);
    }

    private PaymentAdminResponse toResponse(Payment p) {
        return new PaymentAdminResponse(
                p.getId(),
                p.getStudent().getId(),
                p.getStudent().getUser().getFullName(),
                p.getStudent().getStudentId(),
                p.getAmount(),
                p.getStatus().name(),
                p.getType() != null ? p.getType().name() : null,
                p.getMethod() != null ? p.getMethod().name() : null,
                p.getProviderReference(),
                p.getDescription(),
                p.getGatewayTransactionId(),
                p.getCreatedAt()
        );
    }
}

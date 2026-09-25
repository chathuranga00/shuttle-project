package com.shuttle.admin.payment;

import java.math.BigDecimal;
import java.time.Instant;

public record PaymentAdminResponse(
        Long id,
        Long studentId,
        String studentName,
        String studentCode,
        BigDecimal amount,
        String status,
        String type,
        String method,
        String providerReference,
        String description,
        String gatewayTransactionId,
        Instant createdAt
) {}

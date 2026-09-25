package com.shuttle.payment;

import java.math.BigDecimal;

public record PaymentStatusResponse(
        Long       paymentId,
        String     status,      // PENDING | SUCCESS | FAILED | CANCELLED
        BigDecimal amount,
        String     type
) {}

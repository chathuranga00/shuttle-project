package com.shuttle.student.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record PaymentSummary(
        Long       id,
        String     type,
        BigDecimal amount,
        String     status,
        Instant    createdAt
) {}

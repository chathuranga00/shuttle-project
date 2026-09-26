package com.shuttle.driver.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record BoardingItemResponse(
        Long       id,
        Long       studentId,
        String     studentName,
        String     stopName,
        Instant    boardedAt,
        BigDecimal fareAmount,
        String     paymentStatus
) {}

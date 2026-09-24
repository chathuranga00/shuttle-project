package com.shuttle.boarding.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record BoardingConfirmResponse(
        Long       boardingRecordId,
        Long       tripId,
        String     routeName,
        String     stopName,
        BigDecimal fareAmount,
        String     paymentStatus,
        Instant    boardedAt,
        /** true when this response is from an idempotent replay (not a fresh insert). */
        boolean    alreadyBoarded
) {}

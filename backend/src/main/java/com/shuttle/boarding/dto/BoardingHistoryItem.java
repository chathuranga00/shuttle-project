package com.shuttle.boarding.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record BoardingHistoryItem(
        Long       boardingRecordId,
        Long       tripId,
        String     routeName,
        String     busStopName,
        BigDecimal fareAmount,
        String     paymentStatus,
        Instant    boardedAt
) {}

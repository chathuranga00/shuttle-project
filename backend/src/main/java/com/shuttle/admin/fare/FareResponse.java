package com.shuttle.admin.fare;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

public record FareResponse(
        Long       id,
        Long       routeId,
        String     routeName,
        Long       stopId,
        String     stopName,
        BigDecimal amount,
        String     fareClass,
        LocalDate  effectiveFrom,
        LocalDate  effectiveUntil,
        Instant    createdAt
) {}

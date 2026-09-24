package com.shuttle.pass.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PassStatusResponse(
        Long       passId,
        String     status,     // "NONE" | "PENDING" | "ACTIVE" | "EXPIRED" | "CANCELLED"
        LocalDate  validFrom,
        LocalDate  validTo,
        BigDecimal price,
        /** True when the pass is ACTIVE and covers today. */
        boolean    coveringToday,
        /** Configured price for next purchase (from system settings). */
        BigDecimal nextPurchasePrice
) {}

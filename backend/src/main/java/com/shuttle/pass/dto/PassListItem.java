package com.shuttle.pass.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

public record PassListItem(
        Long       passId,
        String     status,
        LocalDate  validFrom,
        LocalDate  validTo,
        BigDecimal price,
        Instant    createdAt
) {}

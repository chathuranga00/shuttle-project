package com.shuttle.admin.fare;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;

public record FareRequest(
        @NotNull                                Long      routeId,
        @NotNull                                Long      stopId,
        @NotNull @DecimalMin("0.01")            BigDecimal amount,
        @NotBlank                               String     fareClass,     // STANDARD | STUDENT | STAFF
        @NotNull                                LocalDate  effectiveFrom,
        /* nullable — null means open-ended */  LocalDate  effectiveUntil
) {}

package com.shuttle.admin.settings;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record SystemConfigRequest(
        @NotNull @Min(10) @Max(5000) Integer    gpsRadiusMetres,
        @NotNull                     Boolean    gpsVerificationEnabled,
        @DecimalMin("0.00")          BigDecimal monthlyPassPrice
) {}

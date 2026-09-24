package com.shuttle.admin.settings;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public record SystemConfigRequest(
        @NotNull @Min(10) @Max(5000) Integer gpsRadiusMetres,
        @NotNull                     Boolean gpsVerificationEnabled
) {}

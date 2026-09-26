package com.shuttle.admin.stop;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record BusStopRequest(
        @NotBlank @Size(max = 150) String name,
        /** Human-readable stop code, e.g. "STOP-001". Auto-generated if blank. */
        @Size(max = 100)           String qrCode,
        @DecimalMin("-90.0")  @DecimalMax("90.0")  BigDecimal latitude,
        @DecimalMin("-180.0") @DecimalMax("180.0") BigDecimal longitude,
        @Size(max = 255)           String address,
        @NotBlank                  String status    // ACTIVE | INACTIVE
) {}

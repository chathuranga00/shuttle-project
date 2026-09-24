package com.shuttle.boarding.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;

public record ValidateBoardingRequest(
        @NotBlank String stopQrPayload,
        Long      tripId,           // optional — required if multiple active trips serve the stop

        // ── Optional GPS fields ──────────────────────────────────────
        @DecimalMin("-90.0")  @DecimalMax("90.0")   Double latitude,
        @DecimalMin("-180.0") @DecimalMax("180.0")  Double longitude,
        /** Horizontal accuracy in metres as reported by the device. */
        Double accuracyMeters
) {}

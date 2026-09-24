package com.shuttle.boarding.dto;

import jakarta.validation.constraints.NotBlank;

public record ValidateBoardingRequest(
        @NotBlank String stopQrPayload,
        Long      tripId              // optional — required if multiple active trips serve the stop
) {}

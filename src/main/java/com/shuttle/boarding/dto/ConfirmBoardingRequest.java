package com.shuttle.boarding.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ConfirmBoardingRequest(
        @NotBlank                   String stopQrPayload,
        @NotNull                    Long   tripId,
        @NotBlank @Size(max = 64)   String idempotencyKey
) {}

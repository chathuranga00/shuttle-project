package com.shuttle.notification.dto;

import jakarta.validation.constraints.NotBlank;

public record DeviceRegisterRequest(
        @NotBlank(message = "Token is required")
        String token,

        String deviceType
) {}

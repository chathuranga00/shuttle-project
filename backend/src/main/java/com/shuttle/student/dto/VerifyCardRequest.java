package com.shuttle.student.dto;

import jakarta.validation.constraints.NotBlank;

public record VerifyCardRequest(
        @NotBlank(message = "Token must not be blank.")
        String token
) {}

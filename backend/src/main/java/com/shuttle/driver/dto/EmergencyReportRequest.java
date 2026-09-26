package com.shuttle.driver.dto;

import jakarta.validation.constraints.NotBlank;

public record EmergencyReportRequest(
        @NotBlank(message = "Emergency type is required")
        String type,

        @NotBlank(message = "Description is required")
        String description,

        String location,

        Long tripId
) {}

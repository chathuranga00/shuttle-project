package com.shuttle.admin.bus;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record BusRequest(
        @NotBlank @Size(max = 50)  String busNumber,
        @NotBlank @Size(max = 20)  String plateNumber,
        @NotNull @Min(1) @Max(200) Integer capacity,
        @Size(max = 100)           String model,
        @NotBlank                  String status   // ACTIVE | MAINTENANCE | RETIRED
) {}

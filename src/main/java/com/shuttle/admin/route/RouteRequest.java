package com.shuttle.admin.route;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public record RouteRequest(
        @NotBlank @Size(max = 150) String name,
        @NotBlank @Size(max = 50)  String code,
        @Size(max = 500)           String description,
        Integer                    estimatedDurationMinutes,
        @NotBlank                  String status,        // ACTIVE | INACTIVE
        @NotNull @Valid List<RouteStopEntry> stops
) {}

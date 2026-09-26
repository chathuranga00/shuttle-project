package com.shuttle.admin.route;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/** A single stop entry in a route definition request. */
public record RouteStopEntry(
        @NotNull Long    busStopId,
        @NotNull @Min(1) Integer stopOrder,
        Integer estimatedOffsetMinutes
) {}

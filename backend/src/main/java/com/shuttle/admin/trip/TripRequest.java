package com.shuttle.admin.trip;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;

public record TripRequest(
        @NotNull Long   routeId,
        @NotNull Long   busId,
        @NotNull Long   driverId,
        @NotNull Instant scheduledStart,
                 Instant scheduledEnd,
                 String  notes
) {}

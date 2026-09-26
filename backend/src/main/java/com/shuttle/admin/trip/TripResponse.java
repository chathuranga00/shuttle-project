package com.shuttle.admin.trip;

import java.time.Instant;

public record TripResponse(
        Long    id,
        Long    routeId,
        String  routeName,
        Long    busId,
        String  busNumber,
        Long    driverId,
        String  driverName,
        String  status,
        Instant scheduledStart,
        Instant scheduledEnd,
        Instant actualStart,
        Instant actualEnd,
        String  notes,
        Instant createdAt,
        Instant updatedAt
) {}

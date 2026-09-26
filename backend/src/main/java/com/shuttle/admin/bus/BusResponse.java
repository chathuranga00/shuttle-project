package com.shuttle.admin.bus;

import java.time.Instant;

public record BusResponse(
        Long    id,
        String  busNumber,
        String  plateNumber,
        int     capacity,
        String  model,
        String  status,
        Instant createdAt,
        Instant updatedAt
) {}

package com.shuttle.driver.dto;

import java.time.Instant;

public record DriverTripHistoryItem(
        Long    id,
        Long    routeId,
        String  routeName,
        Long    busId,
        String  busNumber,
        String  status,
        Instant scheduledStart,
        Instant scheduledEnd,
        Instant actualStart,
        Instant actualEnd,
        int     passengerCount,
        int     monthlyPassCount,
        int     payPerTripCount,
        String  notes,
        Instant createdAt
) {}

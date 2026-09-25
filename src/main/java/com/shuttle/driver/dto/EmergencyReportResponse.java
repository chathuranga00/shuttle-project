package com.shuttle.driver.dto;

import java.time.Instant;

public record EmergencyReportResponse(
        Long    id,
        Long    driverId,
        String  driverName,
        Long    tripId,
        String  type,
        String  description,
        String  location,
        String  status,
        Instant createdAt
) {}

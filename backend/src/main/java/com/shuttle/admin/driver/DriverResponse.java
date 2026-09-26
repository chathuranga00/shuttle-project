package com.shuttle.admin.driver;

import java.time.Instant;
import java.time.LocalDate;

public record DriverResponse(
        Long      driverId,
        Long      userId,
        String    fullName,
        String    email,
        String    phone,
        String    licenseNumber,
        LocalDate licenseExpiry,
        String    driverStatus,
        String    userStatus,
        // Current assignment (null if unassigned)
        Long      assignedBusId,
        String    assignedBusNumber,
        Long      assignedRouteId,
        String    assignedRouteName,
        Instant   createdAt
) {}

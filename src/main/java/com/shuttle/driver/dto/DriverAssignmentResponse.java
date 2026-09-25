package com.shuttle.driver.dto;

import java.util.List;

public record DriverAssignmentResponse(
        Long               driverId,
        String             driverName,
        String             licenseNumber,
        String             driverStatus,
        DriverBusDto       bus,
        DriverRouteDto     route
) {
    public record DriverBusDto(
            Long   id,
            String busNumber,
            String plateNumber,
            int    capacity,
            String status
    ) {}

    public record DriverRouteDto(
            Long                 id,
            String               name,
            String               code,
            String               description,
            Integer              estimatedDurationMinutes,
            String               status,
            List<DriverStopDto>  stops
    ) {}

    public record DriverStopDto(
            Long    id,
            String  name,
            String  qrCode,
            int     sequence,
            Double  latitude,
            Double  longitude
    ) {}
}

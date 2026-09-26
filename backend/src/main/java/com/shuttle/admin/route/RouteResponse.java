package com.shuttle.admin.route;

import java.time.Instant;
import java.util.List;

public record RouteResponse(
        Long                  id,
        String                name,
        String                code,
        String                description,
        Integer               estimatedDurationMinutes,
        String                status,
        List<RouteStopDetail> stops,
        Instant               createdAt,
        Instant               updatedAt
) {}

package com.shuttle.routes;

import java.math.BigDecimal;

/** A route stop enriched with the current STANDARD fare (null if no fare configured). */
public record RouteStopWithFare(
        Long       routeStopId,
        int        stopOrder,
        Integer    estimatedOffsetMinutes,
        Long       busStopId,
        String     stopName,
        String     qrCode,
        BigDecimal latitude,
        BigDecimal longitude,
        String     address,
        String     stopStatus,
        BigDecimal currentFare  // null if no active fare is configured for this stop
) {}

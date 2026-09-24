package com.shuttle.admin.route;

import java.math.BigDecimal;

public record RouteStopDetail(
        Long       routeStopId,
        int        stopOrder,
        Integer    estimatedOffsetMinutes,
        Long       busStopId,
        String     stopName,
        String     qrCode,
        BigDecimal latitude,
        BigDecimal longitude,
        String     address,
        String     stopStatus
) {}

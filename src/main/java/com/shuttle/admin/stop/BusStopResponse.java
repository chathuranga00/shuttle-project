package com.shuttle.admin.stop;

import java.math.BigDecimal;
import java.time.Instant;

public record BusStopResponse(
        Long       id,
        String     name,
        String     qrCode,
        BigDecimal latitude,
        BigDecimal longitude,
        String     address,
        String     status,
        Instant    createdAt,
        Instant    updatedAt
) {}

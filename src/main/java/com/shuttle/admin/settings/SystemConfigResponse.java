package com.shuttle.admin.settings;

import java.math.BigDecimal;

public record SystemConfigResponse(
        int        gpsRadiusMetres,
        boolean    gpsVerificationEnabled,
        BigDecimal monthlyPassPrice
) {}

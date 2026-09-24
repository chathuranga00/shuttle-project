package com.shuttle.admin.settings;

public record SystemConfigResponse(
        int     gpsRadiusMetres,
        boolean gpsVerificationEnabled
) {}

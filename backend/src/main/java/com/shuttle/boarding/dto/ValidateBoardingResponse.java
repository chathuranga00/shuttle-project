package com.shuttle.boarding.dto;

import java.math.BigDecimal;

public record ValidateBoardingResponse(
        boolean    valid,
        String     message,
        String     stopName,
        String     routeName,
        Long       tripId,
        BigDecimal fare        // null when no fare is configured
) {}

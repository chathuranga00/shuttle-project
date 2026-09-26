package com.shuttle.wallet.dto;

import java.math.BigDecimal;

public record TopUpResponse(
        Long       paymentId,
        String     checkoutUrl,
        String     paymentStatus,
        BigDecimal amount
) {}

package com.shuttle.wallet.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record PaymentHistoryItem(
        Long        id,
        String      type,
        BigDecimal  amount,
        String      status,
        String      description,
        Instant     createdAt
) {}

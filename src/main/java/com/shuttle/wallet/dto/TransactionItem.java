package com.shuttle.wallet.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record TransactionItem(
        Long        id,
        String      type,         // CREDIT | DEBIT
        BigDecimal  amount,
        BigDecimal  balanceAfter,
        String      description,
        Instant     createdAt
) {}

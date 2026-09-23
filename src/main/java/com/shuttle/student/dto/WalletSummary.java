package com.shuttle.student.dto;

import java.math.BigDecimal;

public record WalletSummary(
        BigDecimal balance,
        String status
) {}

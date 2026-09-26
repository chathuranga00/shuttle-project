package com.shuttle.wallet.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record TopUpRequest(
        @NotNull @DecimalMin("50.00") BigDecimal amount
) {}

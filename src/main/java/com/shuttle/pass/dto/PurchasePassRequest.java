package com.shuttle.pass.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record PurchasePassRequest(
        /** First day the pass should be valid. Defaults to today if null. */
        LocalDate validFrom
) {}

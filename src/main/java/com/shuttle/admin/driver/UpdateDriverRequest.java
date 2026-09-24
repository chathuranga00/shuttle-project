package com.shuttle.admin.driver;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record UpdateDriverRequest(
        @NotBlank @Size(max = 50) String    licenseNumber,
        LocalDate                           licenseExpiry,
        @NotBlank                 String    status    // ACTIVE | ON_LEAVE | INACTIVE
) {}

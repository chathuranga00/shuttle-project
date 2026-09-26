package com.shuttle.admin.driver;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record CreateDriverRequest(
        @NotBlank @Size(max = 150) String  fullName,
        @NotBlank @Email           String  email,
        @NotBlank @Size(min = 8)   String  password,
        @Size(max = 20) @Pattern(regexp = "^\\+?[0-9\\-\\s]{7,20}$", message = "Invalid phone")
                                   String  phone,
        @NotBlank @Size(max = 50)  String  licenseNumber,
        LocalDate                          licenseExpiry,
        /** Optional: immediately assign to a bus */
        Long                               busId,
        /** Optional: immediately assign to a route */
        Long                               routeId
) {}

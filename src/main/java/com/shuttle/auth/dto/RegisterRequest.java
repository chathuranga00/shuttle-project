package com.shuttle.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(

        @NotBlank(message = "Name is required")
        @Size(max = 150, message = "Name must not exceed 150 characters")
        String name,

        @NotBlank(message = "Email is required")
        @Email(message = "Email must be a valid address")
        String email,

        @NotBlank(message = "Password is required")
        @Size(min = 8, message = "Password must be at least 8 characters")
        String password,

        @NotBlank(message = "Student ID is required")
        @Size(max = 50, message = "Student ID must not exceed 50 characters")
        String studentId,

        @NotBlank(message = "Faculty is required")
        @Size(max = 100, message = "Faculty must not exceed 100 characters")
        String faculty,

        @NotNull(message = "Year is required")
        @Min(value = 1900, message = "Year seems too early")
        @Max(value = 2100, message = "Year seems too far in the future")
        Integer year,

        @Pattern(regexp = "^\\+?[0-9\\-\\s]{7,20}$", message = "Phone number is invalid")
        String phone
) {}

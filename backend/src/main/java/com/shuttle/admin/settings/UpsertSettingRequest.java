package com.shuttle.admin.settings;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpsertSettingRequest(
        @NotBlank @Size(max = 100) String key,
        @NotBlank @Size(max = 500) String value,
        @Size(max = 255)           String description
) {}

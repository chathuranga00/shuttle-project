package com.shuttle.admin.settings;

public record SettingResponse(
        Long   id,
        String key,
        String value,
        String description
) {}

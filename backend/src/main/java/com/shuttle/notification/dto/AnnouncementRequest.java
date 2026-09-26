package com.shuttle.notification.dto;

import jakarta.validation.constraints.NotBlank;

public record AnnouncementRequest(
        @NotBlank(message = "Title is required")
        String title,

        @NotBlank(message = "Message is required")
        String message,

        String targetRole
) {}

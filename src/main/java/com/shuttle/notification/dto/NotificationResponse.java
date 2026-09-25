package com.shuttle.notification.dto;

import com.shuttle.domain.entity.Notification;
import com.shuttle.domain.enums.NotificationType;
import java.time.Instant;

public record NotificationResponse(
        Long id,
        String title,
        String message,
        NotificationType type,
        boolean read,
        Instant createdAt
) {
    public static NotificationResponse from(Notification n) {
        return new NotificationResponse(
                n.getId(),
                n.getTitle(),
                n.getMessage(),
                n.getType(),
                n.isRead(),
                n.getCreatedAt()
        );
    }
}

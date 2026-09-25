package com.shuttle.notification;

import com.shuttle.notification.dto.NotificationCountResponse;
import com.shuttle.notification.dto.NotificationResponse;
import com.shuttle.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
@Tag(name = "Notifications", description = "User notification management")
@SecurityRequirement(name = "bearerAuth")
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    @Operation(summary = "Get notifications for current user")
    public List<NotificationResponse> getNotifications(@AuthenticationPrincipal UserPrincipal principal) {
        return notificationService.getNotificationsForUser(principal.getId());
    }

    @GetMapping("/unread-count")
    @Operation(summary = "Get unread notifications count for current user")
    public NotificationCountResponse getUnreadCount(@AuthenticationPrincipal UserPrincipal principal) {
        return notificationService.getUnreadCount(principal.getId());
    }

    @PatchMapping("/{id}/read")
    @Operation(summary = "Mark a notification as read")
    public NotificationResponse markAsRead(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        return notificationService.markAsRead(id, principal.getId());
    }

    @PatchMapping("/read-all")
    @Operation(summary = "Mark all notifications as read for current user")
    public Map<String, Object> markAllAsRead(@AuthenticationPrincipal UserPrincipal principal) {
        int count = notificationService.markAllAsRead(principal.getId());
        return Map.of("markedCount", count);
    }
}

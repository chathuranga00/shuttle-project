package com.shuttle.admin.announcement;

import com.shuttle.notification.NotificationService;
import com.shuttle.notification.dto.AnnouncementRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/announcements")
@RequiredArgsConstructor
@Tag(name = "Admin Announcements", description = "Broadcast announcements to users")
@SecurityRequirement(name = "bearerAuth")
@PreAuthorize("hasRole('ADMIN')")
public class AnnouncementAdminController {

    private final NotificationService notificationService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Broadcast an announcement to students, drivers, or all users")
    public Map<String, Object> broadcastAnnouncement(@Valid @RequestBody AnnouncementRequest request) {
        int recipientCount = notificationService.sendAnnouncement(request);
        return Map.of(
                "message", "Announcement broadcast successfully",
                "recipientCount", recipientCount
        );
    }
}

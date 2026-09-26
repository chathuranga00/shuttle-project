package com.shuttle.notification;

import com.shuttle.notification.dto.DeviceRegisterRequest;
import com.shuttle.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
@Tag(name = "Devices", description = "Device token management for push notifications")
@SecurityRequirement(name = "bearerAuth")
public class DeviceController {

    private final NotificationService notificationService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Register or update an FCM device token for push notifications")
    public Map<String, String> registerDevice(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody DeviceRegisterRequest request
    ) {
        notificationService.registerDevice(principal.getId(), request);
        return Map.of("message", "Device token registered successfully");
    }
}

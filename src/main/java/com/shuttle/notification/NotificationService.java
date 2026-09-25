package com.shuttle.notification;

import com.shuttle.config.NotificationProperties;
import com.shuttle.domain.entity.DeviceToken;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Notification;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.DeviceTokenRepository;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.NotificationRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.notification.dto.AnnouncementRequest;
import com.shuttle.notification.dto.DeviceRegisterRequest;
import com.shuttle.notification.dto.NotificationCountResponse;
import com.shuttle.notification.dto.NotificationResponse;
import com.shuttle.notification.fcm.FcmPushService;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;
    private final MonthlyPassRepository monthlyPassRepository;
    private final FcmPushService fcmPushService;
    private final NotificationProperties notificationProperties;

    // ── Create and dispatch notification ──────────────────────────────────────

    @Transactional
    public Notification createNotification(User user, String title, String message, NotificationType type) {
        Notification notification = new Notification();
        notification.setUser(user);
        notification.setTitle(title);
        notification.setMessage(message);
        notification.setType(type);
        notification.setRead(false);
        Notification saved = notificationRepository.save(notification);

        // Dispatch FCM push to user's registered devices
        try {
            List<DeviceToken> tokens = deviceTokenRepository.findByUserId(user.getId());
            if (!tokens.isEmpty()) {
                List<String> tokenStrings = tokens.stream().map(DeviceToken::getToken).toList();
                Map<String, String> data = Map.of(
                        "notificationId", String.valueOf(saved.getId()),
                        "type", type.name(),
                        "createdAt", saved.getCreatedAt() != null ? saved.getCreatedAt().toString() : Instant.now().toString()
                );
                fcmPushService.sendMulticast(tokenStrings, title, message, data);
            }
        } catch (Exception e) {
            log.warn("Failed to dispatch push notification for user {}: {}", user.getId(), e.getMessage());
        }

        return saved;
    }

    // ── Query notifications ───────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<NotificationResponse> getNotificationsForUser(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId)
                .stream()
                .map(NotificationResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public NotificationCountResponse getUnreadCount(Long userId) {
        long count = notificationRepository.findByUserIdAndReadFalseOrderByCreatedAtDesc(userId).size();
        return new NotificationCountResponse(count);
    }

    // ── Mark read ─────────────────────────────────────────────────────────────

    @Transactional
    public NotificationResponse markAsRead(Long notificationId, Long userId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Notification not found"));

        if (!notification.getUser().getId().equals(userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "You do not own this notification");
        }

        notification.setRead(true);
        Notification saved = notificationRepository.save(notification);
        return NotificationResponse.from(saved);
    }

    @Transactional
    public int markAllAsRead(Long userId) {
        List<Notification> unreadList = notificationRepository.findByUserIdAndReadFalseOrderByCreatedAtDesc(userId);
        for (Notification n : unreadList) {
            n.setRead(true);
        }
        notificationRepository.saveAll(unreadList);
        return unreadList.size();
    }

    // ── Device registration ───────────────────────────────────────────────────

    @Transactional
    public void registerDevice(Long userId, DeviceRegisterRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "User not found"));

        DeviceToken deviceToken = deviceTokenRepository.findByToken(request.token())
                .orElseGet(() -> {
                    DeviceToken dt = new DeviceToken();
                    dt.setToken(request.token());
                    return dt;
                });

        deviceToken.setUser(user);
        if (request.deviceType() != null && !request.deviceType().isBlank()) {
            deviceToken.setDeviceType(request.deviceType().toUpperCase());
        }
        deviceTokenRepository.save(deviceToken);
        log.info("Registered device token for user {} ({})", user.getId(), deviceToken.getDeviceType());
    }

    // ── Admin Announcement broadcast ──────────────────────────────────────────

    @Transactional
    public int sendAnnouncement(AnnouncementRequest request) {
        List<User> recipients;
        String roleTarget = request.targetRole() != null ? request.targetRole().trim().toUpperCase() : "ALL";

        if ("STUDENT".equals(roleTarget)) {
            recipients = userRepository.findByRoleAndStatus(Role.STUDENT, UserStatus.ACTIVE);
        } else if ("DRIVER".equals(roleTarget)) {
            recipients = userRepository.findByRoleAndStatus(Role.DRIVER, UserStatus.ACTIVE);
        } else {
            recipients = userRepository.findAll().stream()
                    .filter(u -> u.getStatus() == UserStatus.ACTIVE)
                    .toList();
        }

        for (User user : recipients) {
            createNotification(user, request.title(), request.message(), NotificationType.GENERAL);
        }

        log.info("Broadcast announcement '{}' sent to {} users (target: {})",
                request.title(), recipients.size(), roleTarget);
        return recipients.size();
    }

    // ── Scheduled job: Monthly pass expiring in 3 days ────────────────────────

    @Scheduled(cron = "0 0 8 * * *") // Daily at 8:00 AM
    @Transactional
    public int checkMonthlyPassExpiringSoon() {
        LocalDate today = LocalDate.now();
        LocalDate threeDaysLater = today.plusDays(3);

        List<MonthlyPass> expiringPasses = monthlyPassRepository.findActivePassesExpiringBetween(today, threeDaysLater);
        int sentCount = 0;

        for (MonthlyPass pass : expiringPasses) {
            if (pass.getStudent() == null || pass.getStudent().getUser() == null) {
                continue;
            }
            User user = pass.getStudent().getUser();

            // Avoid sending multiple expiring warnings if one was already sent recently
            List<Notification> recentNotifications = notificationRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
            boolean alreadyNotified = recentNotifications.stream()
                    .anyMatch(n -> n.getType() == NotificationType.PASS
                            && n.getTitle().contains("Expiring")
                            && n.getCreatedAt() != null
                            && n.getCreatedAt().isAfter(Instant.now().minus(java.time.Duration.ofDays(2))));

            if (!alreadyNotified) {
                createNotification(
                        user,
                        "Monthly Pass Expiring Soon",
                        "Your monthly pass (#" + pass.getId() + ") expires on " + pass.getValidTo()
                                + ". Renew now to ensure uninterrupted travel.",
                        NotificationType.PASS
                );
                sentCount++;
            }
        }

        log.info("Monthly pass expiry job evaluated {} expiring passes, sent {} notifications.",
                expiringPasses.size(), sentCount);
        return sentCount;
    }

    // ── Low wallet balance trigger ────────────────────────────────────────────

    @Transactional
    public void checkAndNotifyLowBalance(User user, BigDecimal balance) {
        if (user == null || balance == null) {
            return;
        }

        BigDecimal threshold = notificationProperties.lowBalanceThreshold();
        if (balance.compareTo(threshold) < 0) {
            // Check if user was already alerted recently (within 1 day) to avoid spam
            List<Notification> recent = notificationRepository.findByUserIdOrderByCreatedAtDesc(user.getId());
            boolean alertedRecently = recent.stream()
                    .anyMatch(n -> n.getType() == NotificationType.ALERT
                            && n.getTitle().contains("Low Wallet Balance")
                            && n.getCreatedAt() != null
                            && n.getCreatedAt().isAfter(Instant.now().minus(java.time.Duration.ofDays(1))));

            if (!alertedRecently) {
                createNotification(
                        user,
                        "Low Wallet Balance",
                        "Your wallet balance is low (LKR " + balance + "). The minimum suggested balance is LKR "
                                + threshold + ". Please top up your wallet.",
                        NotificationType.ALERT
                );
            }
        }
    }
}

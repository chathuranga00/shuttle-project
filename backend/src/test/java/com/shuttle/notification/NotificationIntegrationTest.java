package com.shuttle.notification;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Notification;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.DeviceTokenRepository;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.NotificationRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.notification.dto.AnnouncementRequest;
import com.shuttle.notification.dto.DeviceRegisterRequest;
import com.shuttle.security.JwtService;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class NotificationIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private NotificationRepository notificationRepository;
    @Autowired private DeviceTokenRepository deviceTokenRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private StudentRepository studentRepository;
    @Autowired private MonthlyPassRepository monthlyPassRepository;
    @Autowired private NotificationService notificationService;
    @Autowired private JwtService jwtService;

    private User studentUser;
    private User otherStudentUser;
    private User adminUser;
    private String studentToken;
    private String otherStudentToken;
    private String adminToken;

    @BeforeEach
    void setUp() {
        notificationRepository.deleteAll();
        deviceTokenRepository.deleteAll();

        studentUser = new User();
        studentUser.setEmail("notify.student@shuttle.dev");
        studentUser.setFullName("Notify Student");
        studentUser.setPasswordHash("hashed");
        studentUser.setRole(Role.STUDENT);
        studentUser.setStatus(UserStatus.ACTIVE);
        studentUser = userRepository.save(studentUser);

        Student student = new Student();
        student.setUser(studentUser);
        student.setStudentId("NOTIFY-001");
        student.setFaculty("Science");
        student.setEnrollmentYear(2024);
        studentRepository.save(student);

        otherStudentUser = new User();
        otherStudentUser.setEmail("other.student@shuttle.dev");
        otherStudentUser.setFullName("Other Student");
        otherStudentUser.setPasswordHash("hashed");
        otherStudentUser.setRole(Role.STUDENT);
        otherStudentUser.setStatus(UserStatus.ACTIVE);
        otherStudentUser = userRepository.save(otherStudentUser);

        adminUser = new User();
        adminUser.setEmail("notify.admin@shuttle.dev");
        adminUser.setFullName("Notify Admin");
        adminUser.setPasswordHash("hashed");
        adminUser.setRole(Role.ADMIN);
        adminUser.setStatus(UserStatus.ACTIVE);
        adminUser = userRepository.save(adminUser);

        studentToken = "Bearer " + jwtService.generateAccessToken(studentUser);
        otherStudentToken = "Bearer " + jwtService.generateAccessToken(otherStudentUser);
        adminToken = "Bearer " + jwtService.generateAccessToken(adminUser);
    }

    @Test
    @DisplayName("GET /api/notifications returns user notifications and unread-count works")
    void testGetNotificationsAndUnreadCount() throws Exception {
        notificationService.createNotification(studentUser, "Welcome", "Welcome to shuttle", NotificationType.GENERAL);
        notificationService.createNotification(studentUser, "Boarding", "Boarded bus", NotificationType.TRIP_UPDATE);

        mockMvc.perform(get("/api/notifications")
                        .header("Authorization", studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].title", is("Boarding")))
                .andExpect(jsonPath("$[0].read", is(false)));

        mockMvc.perform(get("/api/notifications/unread-count")
                        .header("Authorization", studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unreadCount", is(2)));
    }

    @Test
    @DisplayName("PATCH /api/notifications/{id}/read marks single notification as read")
    void testMarkAsRead() throws Exception {
        Notification n = notificationService.createNotification(studentUser, "Payment", "Payment of 500", NotificationType.PAYMENT);

        // Other student cannot mark it as read
        mockMvc.perform(patch("/api/notifications/" + n.getId() + "/read")
                        .header("Authorization", otherStudentToken))
                .andExpect(status().isForbidden());

        // Student owner can mark it as read
        mockMvc.perform(patch("/api/notifications/" + n.getId() + "/read")
                        .header("Authorization", studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.read", is(true)));

        Notification updated = notificationRepository.findById(n.getId()).orElseThrow();
        assertThat(updated.isRead()).isTrue();
    }

    @Test
    @DisplayName("PATCH /api/notifications/read-all marks all user notifications as read")
    void testMarkAllAsRead() throws Exception {
        notificationService.createNotification(studentUser, "Note 1", "Message 1", NotificationType.GENERAL);
        notificationService.createNotification(studentUser, "Note 2", "Message 2", NotificationType.ALERT);

        mockMvc.perform(patch("/api/notifications/read-all")
                        .header("Authorization", studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.markedCount", is(2)));

        List<Notification> unread = notificationRepository.findByUserIdAndReadFalseOrderByCreatedAtDesc(studentUser.getId());
        assertThat(unread).isEmpty();
    }

    @Test
    @DisplayName("POST /api/devices registers FCM device token")
    void testRegisterDeviceToken() throws Exception {
        DeviceRegisterRequest request = new DeviceRegisterRequest("fcm-token-12345", "ANDROID");

        mockMvc.perform(post("/api/devices")
                        .header("Authorization", studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.message", is("Device token registered successfully")));

        assertThat(deviceTokenRepository.findByToken("fcm-token-12345")).isPresent();
    }

    @Test
    @DisplayName("POST /api/admin/announcements broadcasts to targeted users")
    void testAdminAnnouncement() throws Exception {
        AnnouncementRequest req = new AnnouncementRequest("System Maintenance", "Tonight at 11pm", "STUDENT");

        // Non-admin forbidden
        mockMvc.perform(post("/api/admin/announcements")
                        .header("Authorization", studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());

        // Admin broadcasts
        mockMvc.perform(post("/api/admin/announcements")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.recipientCount").value(org.hamcrest.Matchers.greaterThanOrEqualTo(2)));
    }

    @Test
    @DisplayName("Low balance check creates ALERT notification when balance < 200")
    void testLowBalanceAlert() {
        notificationService.checkAndNotifyLowBalance(studentUser, new BigDecimal("150.00"));

        List<Notification> notes = notificationRepository.findByUserIdOrderByCreatedAtDesc(studentUser.getId());
        assertThat(notes).hasSize(1);
        assertThat(notes.get(0).getType()).isEqualTo(NotificationType.ALERT);
        assertThat(notes.get(0).getTitle()).contains("Low Wallet Balance");
    }

    @Test
    @DisplayName("Monthly pass expiring in 3 days triggers notification")
    void testMonthlyPassExpiringTrigger() {
        Student student = studentRepository.findByUserId(studentUser.getId()).orElseThrow();

        MonthlyPass pass = new MonthlyPass();
        pass.setStudent(student);
        pass.setStatus(PassStatus.ACTIVE);
        pass.setValidFrom(LocalDate.now().minusDays(27));
        pass.setValidTo(LocalDate.now().plusDays(2)); // expires in 2 days (within 3 days)
        pass.setPrice(new BigDecimal("1500.00"));
        monthlyPassRepository.save(pass);

        int sent = notificationService.checkMonthlyPassExpiringSoon();
        assertThat(sent).isGreaterThanOrEqualTo(1);

        List<Notification> notes = notificationRepository.findByUserIdOrderByCreatedAtDesc(studentUser.getId());
        assertThat(notes).anyMatch(n -> n.getType() == NotificationType.PASS && n.getTitle().contains("Expiring"));
    }
}

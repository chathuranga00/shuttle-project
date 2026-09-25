package com.shuttle.admin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.admin.settings.SystemConfigRequest;
import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.PaymentMethod;
import com.shuttle.domain.enums.PaymentStatus;
import com.shuttle.domain.enums.PaymentType;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.security.JwtService;
import java.math.BigDecimal;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AdminDashboardAndManagementIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private StudentRepository studentRepository;
    @Autowired private BusRepository busRepository;
    @Autowired private PaymentRepository paymentRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    private String adminToken;
    private String studentToken;
    private Student testStudent;

    @BeforeEach
    void setup() {
        // Create Admin
        User adminUser = new User();
        adminUser.setEmail("admin_test_" + UUID.randomUUID() + "@shuttle.dev");
        adminUser.setPasswordHash(passwordEncoder.encode("Admin@1234"));
        adminUser.setFullName("Admin User");
        adminUser.setRole(Role.ADMIN);
        adminUser.setStatus(UserStatus.ACTIVE);
        adminUser = userRepository.save(adminUser);
        adminToken = "Bearer " + jwtService.generateAccessToken(adminUser);

        // Create Student User
        User studentUser = new User();
        studentUser.setEmail("alice_" + UUID.randomUUID() + "@uni.edu");
        studentUser.setPasswordHash(passwordEncoder.encode("Pass@1234"));
        studentUser.setFullName("Alice Wonder");
        studentUser.setRole(Role.STUDENT);
        studentUser.setStatus(UserStatus.ACTIVE);
        studentUser = userRepository.save(studentUser);
        studentToken = "Bearer " + jwtService.generateAccessToken(studentUser);

        testStudent = new Student();
        testStudent.setUser(studentUser);
        testStudent.setStudentId("STU" + System.currentTimeMillis());
        testStudent.setFaculty("Computing");
        testStudent.setDepartment("Computer Science");
        testStudent.setEnrollmentYear(2024);
        testStudent = studentRepository.save(testStudent);

        // Create a Bus
        Bus bus = new Bus();
        bus.setBusNumber("BUS-" + UUID.randomUUID().toString().substring(0, 8));
        bus.setPlateNumber("WP-NC-" + (System.currentTimeMillis() % 10000));
        bus.setCapacity(40);
        bus.setStatus(BusStatus.ACTIVE);
        busRepository.save(bus);

        // Create a Payment
        Payment payment = new Payment();
        payment.setStudent(testStudent);
        payment.setAmount(new BigDecimal("500.00"));
        payment.setType(PaymentType.WALLET_TOPUP);
        payment.setMethod(PaymentMethod.CARD);
        payment.setStatus(PaymentStatus.SUCCESS);
        payment.setGatewayTransactionId("TX_" + UUID.randomUUID());
        paymentRepository.save(payment);
    }

    @Test
    @DisplayName("GET /api/admin/dashboard returns 200 with dashboard statistics")
    void testGetDashboard() throws Exception {
        mockMvc.perform(get("/api/admin/dashboard")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalStudents", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.totalBuses", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.todayRevenue", notNullValue()))
                .andExpect(jsonPath("$.todayPassengers", notNullValue()));
    }

    @Test
    @DisplayName("GET /api/admin/dashboard forbidden for non-admin")
    void testGetDashboardForbiddenForStudent() throws Exception {
        mockMvc.perform(get("/api/admin/dashboard")
                        .header("Authorization", studentToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("GET /api/admin/students returns paginated students and supports search")
    void testListStudents() throws Exception {
        mockMvc.perform(get("/api/admin/students")
                        .param("page", "0")
                        .param("size", "10")
                        .param("search", "Alice")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$.content[0].fullName", containsString("Alice")))
                .andExpect(jsonPath("$.totalElements", greaterThanOrEqualTo(1)));
    }

    @Test
    @DisplayName("Suspend and activate student via admin endpoints")
    void testSuspendAndActivateStudent() throws Exception {
        // Suspend
        mockMvc.perform(post("/api/admin/students/" + testStudent.getId() + "/suspend")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("SUSPENDED")));

        // Activate
        mockMvc.perform(post("/api/admin/students/" + testStudent.getId() + "/activate")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("ACTIVE")));
    }

    @Test
    @DisplayName("GET /api/admin/payments returns filtered paginated payments")
    void testListPayments() throws Exception {
        mockMvc.perform(get("/api/admin/payments")
                        .param("status", "SUCCESS")
                        .param("page", "0")
                        .param("size", "10")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$.content[0].status", is("SUCCESS")));
    }

    @Test
    @DisplayName("GET /api/admin/reports/{type} with format=json returns report data")
    void testGetReportJson() throws Exception {
        mockMvc.perform(get("/api/admin/reports/daily-passenger")
                        .param("format", "json")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.reportType", is("daily-passenger")))
                .andExpect(jsonPath("$.headers", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$.rows", notNullValue()));
    }

    @Test
    @DisplayName("GET /api/admin/reports/{type} with format=csv returns CSV file")
    void testGetReportCsv() throws Exception {
        mockMvc.perform(get("/api/admin/reports/daily-passenger")
                        .param("format", "csv")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", containsString("text/csv")))
                .andExpect(header().string("Content-Disposition", containsString("report-daily-passenger")))
                .andExpect(content().string(containsString("Date,Total Passengers,Monthly Pass,Pay Per Trip")));
    }

    @Test
    @DisplayName("GET and POST /api/admin/settings/config updates system parameters")
    void testSettingsConfig() throws Exception {
        // Get config
        mockMvc.perform(get("/api/admin/settings/config")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.gpsRadiusMetres", notNullValue()))
                .andExpect(jsonPath("$.gpsVerificationEnabled", notNullValue()))
                .andExpect(jsonPath("$.monthlyPassPrice", notNullValue()));

        // Update config
        SystemConfigRequest updateReq = new SystemConfigRequest(
                200,
                true,
                new BigDecimal("5500.00")
        );

        mockMvc.perform(post("/api/admin/settings/config")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateReq))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.gpsRadiusMetres", is(200)))
                .andExpect(jsonPath("$.gpsVerificationEnabled", is(true)))
                .andExpect(jsonPath("$.monthlyPassPrice", is(5500.00)));
    }
}

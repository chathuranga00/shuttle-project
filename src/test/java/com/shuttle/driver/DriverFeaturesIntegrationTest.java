package com.shuttle.driver;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.admin.trip.TripRequest;
import com.shuttle.admin.trip.TripService;
import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.domain.entity.BoardingRecord;
import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.DriverBusAssignment;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Notification;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.RouteStop;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.StopStatus;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.DriverBusAssignmentRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.EmergencyReportRepository;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.NotificationRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.RouteStopRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.driver.dto.EmergencyReportRequest;
import com.shuttle.security.JwtService;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("Driver Features — Integration Tests")
class DriverFeaturesIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private JwtService jwtService;
    @Autowired private TripService tripService;
    @Autowired private TripRepository tripRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private DriverRepository driverRepository;
    @Autowired private StudentRepository studentRepository;
    @Autowired private BusRepository busRepository;
    @Autowired private RouteRepository routeRepository;
    @Autowired private RouteStopRepository routeStopRepository;
    @Autowired private BusStopRepository busStopRepository;
    @Autowired private BoardingRecordRepository boardingRecordRepository;
    @Autowired private MonthlyPassRepository monthlyPassRepository;
    @Autowired private DriverBusAssignmentRepository assignmentRepository;
    @Autowired private EmergencyReportRepository emergencyReportRepository;
    @Autowired private NotificationRepository notificationRepository;
    @Autowired private AuthService authService;
    @Autowired private PasswordEncoder passwordEncoder;

    private String driver1Token;
    private String driver2Token;
    private Driver driver1;
    private Driver driver2;
    private Long busId;
    private Long routeId;
    private Long stopId;
    private Long trip1Id;

    @BeforeEach
    @Transactional
    void setUp() {
        // ── Admin user for notification checks ───────────────────────────────
        if (!userRepository.existsByEmail("admin_driver_test@test.com")) {
            User admin = new User();
            admin.setEmail("admin_driver_test@test.com");
            admin.setPasswordHash(passwordEncoder.encode("Password1!"));
            admin.setFullName("Admin Tester");
            admin.setRole(Role.ADMIN);
            admin.setStatus(UserStatus.ACTIVE);
            userRepository.save(admin);
        }

        // ── Driver 1 ──────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("driver1@test.com")) {
            User u1 = new User();
            u1.setEmail("driver1@test.com");
            u1.setPasswordHash(passwordEncoder.encode("Password1!"));
            u1.setFullName("Driver One");
            u1.setRole(Role.DRIVER);
            u1.setStatus(UserStatus.ACTIVE);
            userRepository.save(u1);

            Driver d1 = new Driver();
            d1.setUser(u1);
            d1.setLicenseNumber("LIC-DRV-001");
            d1.setStatus(DriverStatus.ACTIVE);
            driverRepository.save(d1);
        }
        User u1 = userRepository.findByEmail("driver1@test.com").orElseThrow();
        driver1 = driverRepository.findByUserId(u1.getId()).orElseThrow();
        driver1Token = jwtService.generateAccessToken(u1);

        // ── Driver 2 ──────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("driver2@test.com")) {
            User u2 = new User();
            u2.setEmail("driver2@test.com");
            u2.setPasswordHash(passwordEncoder.encode("Password1!"));
            u2.setFullName("Driver Two");
            u2.setRole(Role.DRIVER);
            u2.setStatus(UserStatus.ACTIVE);
            userRepository.save(u2);

            Driver d2 = new Driver();
            d2.setUser(u2);
            d2.setLicenseNumber("LIC-DRV-002");
            d2.setStatus(DriverStatus.ACTIVE);
            driverRepository.save(d2);
        }
        User u2 = userRepository.findByEmail("driver2@test.com").orElseThrow();
        driver2 = driverRepository.findByUserId(u2.getId()).orElseThrow();
        driver2Token = jwtService.generateAccessToken(u2);

        // Cancel previous trips and assignments to isolate tests
        tripRepository.findByDriverId(driver1.getId()).forEach(t -> {
            t.setStatus(TripStatus.CANCELLED);
            tripRepository.save(t);
        });
        tripRepository.findByDriverId(driver2.getId()).forEach(t -> {
            t.setStatus(TripStatus.CANCELLED);
            tripRepository.save(t);
        });
        tripRepository.flush();

        assignmentRepository.closeAssignmentsForDriver(driver1.getId(), Instant.now());
        assignmentRepository.closeAssignmentsForDriver(driver2.getId(), Instant.now());
        assignmentRepository.flush();

        // ── Bus & Route ───────────────────────────────────────────────────────
        long suffix = System.nanoTime();
        Bus bus = new Bus();
        bus.setBusNumber("BUS-DRV-" + suffix);
        bus.setPlateNumber("PLT-" + suffix % 100000);
        bus.setCapacity(45);
        bus.setStatus(BusStatus.ACTIVE);
        busId = busRepository.save(bus).getId();

        Route route = new Route();
        route.setName("Campus Express " + suffix);
        route.setCode("RT-DRV-" + suffix);
        route.setStatus(RouteStatus.ACTIVE);
        routeId = routeRepository.save(route).getId();

        BusStop stop = new BusStop();
        stop.setName("Campus Gate " + suffix);
        stop.setQrCode("STOP-DRV-" + suffix);
        stop.setStatus(StopStatus.ACTIVE);
        stopId = busStopRepository.save(stop).getId();

        RouteStop rs = new RouteStop();
        rs.setRoute(route);
        rs.setBusStop(stop);
        rs.setStopOrder(1);
        routeStopRepository.save(rs);

        // Assign bus & route to driver1
        DriverBusAssignment assignment = new DriverBusAssignment();
        assignment.setDriver(driver1);
        assignment.setBus(bus);
        assignment.setRoute(route);
        assignment.setAssignedAt(Instant.now());
        assignmentRepository.save(assignment);

        // Create a scheduled trip for driver1 today
        trip1Id = tripService.create(new TripRequest(
                routeId, busId, driver1.getId(),
                Instant.now().plusSeconds(1800),
                Instant.now().plusSeconds(5400),
                "Morning express trip")).id();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. GET /api/trips/current
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("GET /api/trips/current — returns assigned trip for today for authenticated driver")
    void getCurrentTrip_returnsAssignedTripForToday() throws Exception {
        mockMvc.perform(get("/api/trips/current")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(trip1Id))
                .andExpect(jsonPath("$.driverId").value(driver1.getId()))
                .andExpect(jsonPath("$.status").value("SCHEDULED"));
    }

    @Test
    @DisplayName("GET /api/trips/current — returns active trip when in progress")
    void getCurrentTrip_returnsActiveTripWhenInProgress() throws Exception {
        // Start the trip
        tripService.startTrip(trip1Id);

        mockMvc.perform(get("/api/trips/current")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(trip1Id))
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.actualStart", notNullValue()));
    }

    @Test
    @DisplayName("GET /api/trips/current — returns 404 NO_CURRENT_TRIP when driver has no trip for today")
    void getCurrentTrip_noTripToday_returns404() throws Exception {
        mockMvc.perform(get("/api/trips/current")
                        .header("Authorization", "Bearer " + driver2Token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NO_CURRENT_TRIP"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. POST /api/trips/{id}/start
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/trips/{id}/start — driver starts assigned trip (SCHEDULED → IN_PROGRESS)")
    void startTrip_assignedDriver_succeeds() throws Exception {
        mockMvc.perform(post("/api/trips/" + trip1Id + "/start")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(trip1Id))
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.actualStart", notNullValue()));
    }

    @Test
    @DisplayName("POST /api/trips/{id}/start — driver cannot start another driver's trip (403 Forbidden)")
    void startTrip_otherDriver_returns403() throws Exception {
        mockMvc.perform(post("/api/trips/" + trip1Id + "/start")
                        .header("Authorization", "Bearer " + driver2Token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("POST /api/trips/{id}/start — cannot start already active trip (409 Conflict)")
    void startTrip_alreadyActive_returns409() throws Exception {
        tripService.startTrip(trip1Id);

        mockMvc.perform(post("/api/trips/" + trip1Id + "/start")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_TRIP_TRANSITION"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. POST /api/trips/{id}/end
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/trips/{id}/end — driver ends active trip (IN_PROGRESS → COMPLETED)")
    void endTrip_activeTrip_succeeds() throws Exception {
        tripService.startTrip(trip1Id);

        mockMvc.perform(post("/api/trips/" + trip1Id + "/end")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(trip1Id))
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.actualEnd", notNullValue()));
    }

    @Test
    @DisplayName("POST /api/trips/{id}/end — end is ONLY allowed for ACTIVE trips (409 Conflict on SCHEDULED)")
    void endTrip_scheduledTrip_returns409() throws Exception {
        mockMvc.perform(post("/api/trips/" + trip1Id + "/end")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_TRIP_TRANSITION"));
    }

    @Test
    @DisplayName("POST /api/trips/{id}/end — driver cannot end another driver's trip (403 Forbidden)")
    void endTrip_otherDriver_returns403() throws Exception {
        tripService.startTrip(trip1Id);

        mockMvc.perform(post("/api/trips/" + trip1Id + "/end")
                        .header("Authorization", "Bearer " + driver2Token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. GET /api/driver/trips/{id}/summary
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("GET /api/driver/trips/{id}/summary — returns total passengers, pass vs pay-per-trip split, recent boardings")
    void getTripSummary_returnsCorrectCountsAndBoardings() throws Exception {
        tripService.startTrip(trip1Id);

        // Register student 1
        String email1 = "student_sum1_" + System.nanoTime() + "@test.com";
        authService.register(new RegisterRequest("Student One", email1, "Password1!", "S001", "IT", 2024, null));
        User s1User = userRepository.findByEmail(email1).orElseThrow();
        Student s1 = studentRepository.findByUserId(s1User.getId()).orElseThrow();

        // Register student 2
        String email2 = "student_sum2_" + System.nanoTime() + "@test.com";
        authService.register(new RegisterRequest("Student Two", email2, "Password1!", "S002", "IT", 2024, null));
        User s2User = userRepository.findByEmail(email2).orElseThrow();
        Student s2 = studentRepository.findByUserId(s2User.getId()).orElseThrow();

        // Monthly pass for student 1
        MonthlyPass pass = new MonthlyPass();
        pass.setStudent(s1);
        pass.setValidFrom(LocalDate.now().minusDays(5));
        pass.setValidTo(LocalDate.now().plusDays(25));
        pass.setPrice(new BigDecimal("2500.00"));
        pass.setStatus(PassStatus.ACTIVE);
        pass = monthlyPassRepository.save(pass);

        var tripEntity = tripRepository.findById(trip1Id).orElseThrow();
        var stopEntity = busStopRepository.findById(stopId).orElseThrow();

        // Boarding 1: Monthly pass
        BoardingRecord b1 = new BoardingRecord();
        b1.setTrip(tripEntity);
        b1.setStudent(s1);
        b1.setBusStop(stopEntity);
        b1.setBoardedAt(Instant.now().minusSeconds(120));
        b1.setFareAmount(BigDecimal.ZERO);
        b1.setMonthlyPass(pass);
        b1.setPaymentStatus("PASS");
        b1.setIdempotencyKey(UUID.randomUUID().toString());
        boardingRecordRepository.save(b1);

        // Boarding 2: Pay-per-trip
        BoardingRecord b2 = new BoardingRecord();
        b2.setTrip(tripEntity);
        b2.setStudent(s2);
        b2.setBusStop(stopEntity);
        b2.setBoardedAt(Instant.now().minusSeconds(60));
        b2.setFareAmount(new BigDecimal("100.00"));
        b2.setPaymentStatus("PAID");
        b2.setIdempotencyKey(UUID.randomUUID().toString());
        boardingRecordRepository.save(b2);

        mockMvc.perform(get("/api/driver/trips/" + trip1Id + "/summary")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tripId").value(trip1Id))
                .andExpect(jsonPath("$.totalPassengers").value(2))
                .andExpect(jsonPath("$.monthlyPassCount").value(1))
                .andExpect(jsonPath("$.payPerTripCount").value(1))
                .andExpect(jsonPath("$.recentBoardings", hasSize(2)))
                .andExpect(jsonPath("$.recentBoardings[0].studentName").value("Student Two"))
                .andExpect(jsonPath("$.recentBoardings[0].paymentStatus").value("PAID"))
                .andExpect(jsonPath("$.recentBoardings[1].studentName").value("Student One"))
                .andExpect(jsonPath("$.recentBoardings[1].paymentStatus").value("PASS"));
    }

    @Test
    @DisplayName("GET /api/driver/trips/{id}/summary — driver cannot view summary of another driver's trip (403)")
    void getTripSummary_otherDriver_returns403() throws Exception {
        mockMvc.perform(get("/api/driver/trips/" + trip1Id + "/summary")
                        .header("Authorization", "Bearer " + driver2Token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. POST /api/driver/emergency-report
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("POST /api/driver/emergency-report — stores report and creates admin notification")
    void emergencyReport_storesReportAndNotifiesAdmin() throws Exception {
        int notifCountBefore = notificationRepository.findAll().size();

        EmergencyReportRequest req = new EmergencyReportRequest(
                "BREAKDOWN",
                "Flat tyre near main junction",
                "Main Junction, Stop 3",
                trip1Id
        );

        mockMvc.perform(post("/api/driver/emergency-report")
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id", notNullValue()))
                .andExpect(jsonPath("$.driverId").value(driver1.getId()))
                .andExpect(jsonPath("$.type").value("BREAKDOWN"))
                .andExpect(jsonPath("$.description").value("Flat tyre near main junction"))
                .andExpect(jsonPath("$.location").value("Main Junction, Stop 3"))
                .andExpect(jsonPath("$.status").value("REPORTED"));

        // Verify admin notification was created
        List<Notification> notifs = notificationRepository.findAll();
        assertThat(notifs.size()).isGreaterThan(notifCountBefore);

        Notification alert = notifs.stream()
                .filter(n -> n.getType() == NotificationType.ALERT && n.getTitle().contains("BREAKDOWN"))
                .findFirst().orElseThrow();
        assertThat(alert.getMessage()).contains("Flat tyre near main junction");
        assertThat(alert.getMessage()).contains("Main Junction, Stop 3");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. GET /api/driver/trips/history
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("GET /api/driver/trips/history — returns driver trip history")
    void getTripHistory_returnsDriverTrips() throws Exception {
        mockMvc.perform(get("/api/driver/trips/history")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", notNullValue()))
                .andExpect(jsonPath("$[0].id").value(trip1Id));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. GET /api/driver/assignment
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("GET /api/driver/assignment — returns assigned bus and route with stops")
    void getAssignment_returnsAssignedBusAndRoute() throws Exception {
        mockMvc.perform(get("/api/driver/assignment")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.driverId").value(driver1.getId()))
                .andExpect(jsonPath("$.bus.id").value(busId))
                .andExpect(jsonPath("$.route.id").value(routeId))
                .andExpect(jsonPath("$.route.stops", hasSize(1)));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Access control: Drivers must NOT access payment processing
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Driver CANNOT access /api/wallet (403 Forbidden)")
    void driverCannotAccessWallet() throws Exception {
        mockMvc.perform(get("/api/wallet")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Driver CANNOT access /api/wallet/top-up (403 Forbidden)")
    void driverCannotAccessWalletTopUp() throws Exception {
        mockMvc.perform(post("/api/wallet/top-up")
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\": 500}"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Driver CANNOT access /api/payment/history (403 Forbidden)")
    void driverCannotAccessPaymentHistory() throws Exception {
        mockMvc.perform(get("/api/payment/history")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Driver CANNOT access /api/payment/status/{id} (403 Forbidden)")
    void driverCannotAccessPaymentStatus() throws Exception {
        mockMvc.perform(get("/api/payment/status/1")
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isForbidden());
    }
}

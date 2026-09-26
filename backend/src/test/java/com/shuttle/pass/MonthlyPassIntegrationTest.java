package com.shuttle.pass;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.admin.stop.BusStopService;
import com.shuttle.admin.trip.TripRequest;
import com.shuttle.admin.trip.TripService;
import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.boarding.dto.ConfirmBoardingRequest;
import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.RouteStop;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.StopStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.RouteStopRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.pass.dto.PurchasePassRequest;
import com.shuttle.security.JwtService;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("Monthly Pass integration tests")
class MonthlyPassIntegrationTest {

    @Autowired private MockMvc                mockMvc;
    @Autowired private ObjectMapper           objectMapper;
    @Autowired private AuthService            authService;
    @Autowired private JwtService             jwtService;
    @Autowired private TripService            tripService;
    @Autowired private BusStopService         busStopService;
    @Autowired private MonthlyPassRepository  passRepository;
    @Autowired private UserRepository         userRepository;
    @Autowired private StudentRepository      studentRepository;
    @Autowired private DriverRepository       driverRepository;
    @Autowired private BusRepository          busRepository;
    @Autowired private RouteRepository        routeRepository;
    @Autowired private RouteStopRepository    routeStopRepository;
    @Autowired private BusStopRepository      busStopRepository;
    @Autowired private PasswordEncoder        passwordEncoder;

    private static final AtomicInteger seq = new AtomicInteger(0);

    private String studentToken;
    private Long   studentId;
    private Long   tripId;
    private String stopQrPayload;
    private Long   driverId;

    @BeforeEach
    void setUp() {
        int n = seq.incrementAndGet();

        // ── Student ───────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("pass_student@test.com")) {
            authService.register(new RegisterRequest(
                    "Pass Student", "pass_student@test.com",
                    "Password1!", "PS001", "Science", 2024, null));
        }
        User studentUser = userRepository.findByEmail("pass_student@test.com").orElseThrow();
        studentToken = jwtService.generateAccessToken(studentUser);
        studentId    = studentRepository.findByUserId(studentUser.getId()).orElseThrow().getId();

        // Cancel/expire any lingering passes from previous tests
        passRepository.findByStudentId(studentId).forEach(p -> {
            p.setStatus(PassStatus.CANCELLED);
            passRepository.save(p);
        });
        passRepository.flush();

        // ── Driver ────────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("pass_driver@test.com")) {
            User du = new User();
            du.setEmail("pass_driver@test.com");
            du.setPasswordHash(passwordEncoder.encode("Password1!"));
            du.setFullName("Pass Driver");
            du.setRole(Role.DRIVER);
            du.setStatus(UserStatus.ACTIVE);
            userRepository.save(du);
            Driver d = new Driver();
            d.setUser(du);
            d.setLicenseNumber("LIC-PS-001");
            d.setStatus(DriverStatus.ACTIVE);
            driverRepository.save(d);
        }
        driverId = driverRepository.findAll().stream()
                .filter(d -> d.getLicenseNumber().equals("LIC-PS-001"))
                .findFirst().orElseThrow().getId();

        // ── Bus ───────────────────────────────────────────────────────────────
        Bus bus = new Bus();
        bus.setBusNumber("PS-BUS-" + n);
        bus.setPlateNumber("PS-PLT-" + n);
        bus.setCapacity(40);
        bus.setStatus(BusStatus.ACTIVE);
        Long busId = busRepository.save(bus).getId();

        // ── Route + Stop ──────────────────────────────────────────────────────
        Route route = new Route();
        route.setName("Pass Route " + n);
        route.setCode("PS-RT-" + n);
        route.setStatus(RouteStatus.ACTIVE);
        Long routeId = routeRepository.save(route).getId();

        BusStop stop = new BusStop();
        stop.setName("Pass Stop " + n);
        stop.setQrCode("PS-STOP-" + n);
        stop.setStatus(StopStatus.ACTIVE);
        Long stopIdLocal = busStopRepository.saveAndFlush(stop).getId();

        RouteStop rs = new RouteStop();
        rs.setRoute(routeRepository.findById(routeId).orElseThrow());
        rs.setBusStop(stop);
        rs.setStopOrder(1);
        routeStopRepository.saveAndFlush(rs);

        stopQrPayload = busStopService.getQrPayload(stopIdLocal).signedPayload();

        // ── Trip ──────────────────────────────────────────────────────────────
        tripId = tripService.create(new TripRequest(routeId, busId, driverId,
                Instant.now().plusSeconds(600), null, null)).id();
    }

    private String auth() { return "Bearer " + studentToken; }
    private String key()  { return UUID.randomUUID().toString(); }
    private void   startTrip() { tripService.startTrip(tripId); }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET /api/monthly-pass/status
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("GET /status — no pass → status=NONE")
    void status_noPass_returnsNone() throws Exception {
        mockMvc.perform(get("/api/monthly-pass/status")
                .header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("NONE"))
                .andExpect(jsonPath("$.coveringToday").value(false))
                .andExpect(jsonPath("$.nextPurchasePrice", notNullValue()));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // POST /api/monthly-pass/purchase
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("POST /purchase — mock-paid enabled → status=ACTIVE immediately")
    void purchase_mockPaid_returnsActive() throws Exception {
        mockMvc.perform(post("/api/monthly-pass/purchase")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.coveringToday").value(true))
                .andExpect(jsonPath("$.passId", notNullValue()));
    }

    @Test
    @DisplayName("POST /purchase × 2 — overlapping purchase returns 409 PASS_OVERLAP")
    void purchase_duplicate_returnsConflict() throws Exception {
        // First purchase
        mockMvc.perform(post("/api/monthly-pass/purchase")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isCreated());

        // Second overlapping purchase
        mockMvc.perform(post("/api/monthly-pass/purchase")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PASS_OVERLAP"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Boarding with active pass → fare=0, paymentStatus=PASS
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Active pass: boarding confirms with fareAmount=0 and paymentStatus=PASS")
    void boarding_activePass_fareZeroPaymentPass() throws Exception {
        // Purchase a pass (mock-paid → immediately ACTIVE)
        mockMvc.perform(post("/api/monthly-pass/purchase")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isCreated());

        startTrip();

        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, key(),
                                null, null, null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fareAmount").value(0))
                .andExpect(jsonPath("$.paymentStatus").value("PASS"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Expired pass falls back to normal fare (UNPAID)
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Expired pass: boarding falls back to normal fare (UNPAID)")
    void boarding_expiredPass_fallsBackToFare() throws Exception {
        // Insert an already-expired pass directly
        var student = studentRepository.findById(studentId).orElseThrow();
        MonthlyPass expiredPass = new MonthlyPass();
        expiredPass.setStudent(student);
        expiredPass.setValidFrom(LocalDate.now().minusMonths(2));
        expiredPass.setValidTo(LocalDate.now().minusDays(1));   // expired yesterday
        expiredPass.setPrice(new BigDecimal("2500.00"));
        expiredPass.setStatus(PassStatus.EXPIRED);
        passRepository.saveAndFlush(expiredPass);

        startTrip();

        // No active pass covering today → should use normal fare (null here since no fare seeded)
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, key(),
                                null, null, null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paymentStatus").value("UNPAID"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Overlapping purchase rejected
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Purchasing when an ACTIVE pass already covers the period → 409")
    void purchase_whenActiveExists_rejectsOverlap() throws Exception {
        // Insert an active pass for this month
        var student = studentRepository.findById(studentId).orElseThrow();
        MonthlyPass active = new MonthlyPass();
        active.setStudent(student);
        active.setValidFrom(LocalDate.now().withDayOfMonth(1));
        active.setValidTo(LocalDate.now().withDayOfMonth(1).plusMonths(1).minusDays(1));
        active.setPrice(new BigDecimal("2500.00"));
        active.setStatus(PassStatus.ACTIVE);
        passRepository.saveAndFlush(active);

        mockMvc.perform(post("/api/monthly-pass/purchase")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PASS_OVERLAP"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PassExpiryJob
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("PassExpiryJob marks overdue ACTIVE passes as EXPIRED")
    void expiryJob_marksOverduePassesExpired(@Autowired PassExpiryJob passExpiryJob) {
        var student = studentRepository.findById(studentId).orElseThrow();
        MonthlyPass overdue = new MonthlyPass();
        overdue.setStudent(student);
        overdue.setValidFrom(LocalDate.now().minusMonths(2));
        overdue.setValidTo(LocalDate.now().minusDays(1)); // expired yesterday
        overdue.setPrice(new BigDecimal("2500.00"));
        overdue.setStatus(PassStatus.ACTIVE);             // still ACTIVE before job runs
        passRepository.saveAndFlush(overdue);

        passExpiryJob.expireOldPasses();

        MonthlyPass after = passRepository.findById(overdue.getId()).orElseThrow();
        assertThat(after.getStatus()).isEqualTo(PassStatus.EXPIRED);
    }
}

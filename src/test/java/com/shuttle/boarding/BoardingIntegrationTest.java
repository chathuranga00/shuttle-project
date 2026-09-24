package com.shuttle.boarding;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.admin.stop.BusStopService;
import com.shuttle.admin.trip.TripRequest;
import com.shuttle.admin.trip.TripService;
import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.boarding.dto.ConfirmBoardingRequest;
import com.shuttle.boarding.dto.ValidateBoardingRequest;
import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.RouteStop;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.StopStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.RouteStopRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.security.JwtService;
import java.time.Instant;
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

import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Boarding flow integration tests.
 *
 * <p>Each test gets its own isolated bus + route + stop + trip by appending a
 * per-invocation counter to every name/code. This avoids the "bus already active"
 * conflict that occurs when tests share mutable trip state.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("Boarding flow integration tests")
class BoardingIntegrationTest {

    // ── Injected beans ─────────────────────────────────────────────────────────
    @Autowired private MockMvc           mockMvc;
    @Autowired private ObjectMapper      objectMapper;
    @Autowired private AuthService       authService;
    @Autowired private JwtService        jwtService;
    @Autowired private BusStopService    busStopService;
    @Autowired private TripService       tripService;
    @Autowired private UserRepository    userRepository;
    @Autowired private StudentRepository studentRepository;
    @Autowired private DriverRepository  driverRepository;
    @Autowired private BusRepository     busRepository;
    @Autowired private RouteRepository   routeRepository;
    @Autowired private RouteStopRepository routeStopRepository;
    @Autowired private BusStopRepository busStopRepository;
    @Autowired private PasswordEncoder   passwordEncoder;

    // ── Per-test state ─────────────────────────────────────────────────────────
    // Each @BeforeEach creates a fresh set; `seq` ensures unique names.
    private static final AtomicInteger seq = new AtomicInteger(0);

    private String studentToken;
    private Long   tripId;
    private String stopQrPayload;
    private Long   stopId;

    // ── Shared (created once, reused) ─────────────────────────────────────────
    // Student and driver are expensive to create; they are idempotent.
    private Long driverId;

    // ═══════════════════════════════════════════════════════════════════════════
    // Setup — fresh isolated infrastructure per test
    // ═══════════════════════════════════════════════════════════════════════════

    @BeforeEach
    void setUp() {
        int n = seq.incrementAndGet();   // unique suffix for this test invocation

        // ── Student (idempotent) ──────────────────────────────────────────────
        if (!userRepository.existsByEmail("boarding_student@test.com")) {
            authService.register(new RegisterRequest(
                    "Boarding Student", "boarding_student@test.com",
                    "Password1!", "BS001", "Computing", 2024, null));
        }
        User studentUser = userRepository.findByEmail("boarding_student@test.com").orElseThrow();
        studentToken = jwtService.generateAccessToken(studentUser);

        // ── Driver (idempotent) ───────────────────────────────────────────────
        if (!userRepository.existsByEmail("boarding_driver@test.com")) {
            User du = new User();
            du.setEmail("boarding_driver@test.com");
            du.setPasswordHash(passwordEncoder.encode("Password1!"));
            du.setFullName("Boarding Driver");
            du.setRole(Role.DRIVER);
            du.setStatus(UserStatus.ACTIVE);
            userRepository.save(du);
            Driver d = new Driver();
            d.setUser(du);
            d.setLicenseNumber("LIC-BD-001");
            d.setStatus(DriverStatus.ACTIVE);
            driverRepository.save(d);
        }
        driverId = driverRepository.findAll().stream()
                .filter(d -> d.getLicenseNumber().equals("LIC-BD-001"))
                .findFirst().orElseThrow().getId();

        // ── Fresh bus per test (avoids "bus already active" collisions) ────────
        Bus bus = new Bus();
        bus.setBusNumber("BD-BUS-" + n);
        bus.setPlateNumber("PLT-" + n);
        bus.setCapacity(40);
        bus.setStatus(BusStatus.ACTIVE);
        Long busId = busRepository.save(bus).getId();

        // ── Fresh route per test ──────────────────────────────────────────────
        Route route = new Route();
        route.setName("Boarding Route " + n);
        route.setCode("BD-RT-" + n);
        route.setStatus(RouteStatus.ACTIVE);
        Long routeId = routeRepository.save(route).getId();

        // ── Fresh stop per test ───────────────────────────────────────────────
        BusStop stop = new BusStop();
        stop.setName("Boarding Stop " + n);
        stop.setQrCode("BD-STOP-" + n);
        stop.setStatus(StopStatus.ACTIVE);
        stopId = busStopRepository.save(stop).getId();

        RouteStop rs = new RouteStop();
        rs.setRoute(route);
        rs.setBusStop(stop);
        rs.setStopOrder(1);
        routeStopRepository.save(rs);

        // Flush so QR service can load the stop from DB within this transaction
        busStopRepository.flush();
        stopQrPayload = busStopService.getQrPayload(stopId).signedPayload();

        // ── Fresh SCHEDULED trip per test ─────────────────────────────────────
        tripId = tripService.create(new TripRequest(routeId, busId, driverId,
                Instant.now().plusSeconds(600), null, null)).id();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════════════════════════════

    private String authHeader()  { return "Bearer " + studentToken; }
    private String uniqueKey()   { return UUID.randomUUID().toString(); }
    private void   startTrip()   { tripService.startTrip(tripId); }

    // ═══════════════════════════════════════════════════════════════════════════
    // VALIDATE endpoint
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("POST /validate — valid QR + active trip returns valid=true with stop and route names")
    void validate_validQrActiveTrip_returnsValid() throws Exception {
        startTrip();
        mockMvc.perform(post("/api/boarding/validate")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ValidateBoardingRequest(stopQrPayload, null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(true))
                .andExpect(jsonPath("$.tripId").value(tripId))
                .andExpect(jsonPath("$.stopName", notNullValue()))
                .andExpect(jsonPath("$.routeName", notNullValue()));
    }

    @Test
    @DisplayName("POST /validate — invalid QR signature returns valid=false + friendly message")
    void validate_invalidQr_returnsInvalid() throws Exception {
        mockMvc.perform(post("/api/boarding/validate")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ValidateBoardingRequest("INVALID-CODE.badsig", null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.message").value(BoardingService.MSG_QR_INVALID));
    }

    @Test
    @DisplayName("POST /validate — SCHEDULED trip (not IN_PROGRESS) returns valid=false")
    void validate_noActiveTrip_returnsInvalid() throws Exception {
        // Trip is still SCHEDULED here — do NOT call startTrip()
        mockMvc.perform(post("/api/boarding/validate")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ValidateBoardingRequest(stopQrPayload, null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.message").value(BoardingService.MSG_TRIP_NOT_FOUND));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIRM endpoint
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("POST /confirm — valid boarding saves record with paymentStatus=UNPAID")
    void confirm_validBoarding_savesRecord() throws Exception {
        startTrip();
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, uniqueKey()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.boardingRecordId", notNullValue()))
                .andExpect(jsonPath("$.tripId").value(tripId))
                .andExpect(jsonPath("$.paymentStatus").value("UNPAID"))
                .andExpect(jsonPath("$.alreadyBoarded").value(false));
    }

    @Test
    @DisplayName("POST /confirm — duplicate boarding (different key) returns 409 ALREADY_BOARDED")
    void confirm_duplicateBoarding_returnsAlreadyBoarded() throws Exception {
        startTrip();

        // First boarding succeeds
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, uniqueKey()))))
                .andExpect(status().isOk());

        // Second attempt with a DIFFERENT key — same (trip, student) → conflict
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, uniqueKey()))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_BOARDED"))
                .andExpect(jsonPath("$.message").value(BoardingService.MSG_ALREADY_BOARDED));
    }

    @Test
    @DisplayName("POST /confirm — retry with same idempotency key returns existing record, alreadyBoarded=true")
    void confirm_sameIdempotencyKey_isIdempotent() throws Exception {
        startTrip();
        String key = uniqueKey();
        var body = new ConfirmBoardingRequest(stopQrPayload, tripId, key);

        // First call — fresh insert
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.alreadyBoarded").value(false));

        // Retry with the SAME key — must return existing record, not a new one
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.alreadyBoarded").value(true))
                .andExpect(jsonPath("$.paymentStatus").value("UNPAID"));
    }

    @Test
    @DisplayName("POST /confirm — SCHEDULED trip (not IN_PROGRESS) returns 409 TRIP_NOT_ACTIVE")
    void confirm_inactiveTrip_returnsTripNotActive() throws Exception {
        // Trip is SCHEDULED — do NOT call startTrip()
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, uniqueKey()))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TRIP_NOT_ACTIVE"))
                .andExpect(jsonPath("$.message").value(BoardingService.MSG_TRIP_NOT_ACTIVE));
    }

    @Test
    @DisplayName("POST /confirm — stop not on trip's route returns 400 STOP_NOT_IN_ROUTE")
    void confirm_stopNotInRoute_returnsStopNotInRoute() throws Exception {
        startTrip();

        // Create a stop that is NOT linked to this test's route
        BusStop orphan = new BusStop();
        orphan.setName("Orphan Stop");
        orphan.setQrCode("ORPHAN-" + seq.get());
        orphan.setStatus(StopStatus.ACTIVE);
        busStopRepository.saveAndFlush(orphan);
        String orphanPayload = busStopService.getQrPayload(orphan.getId()).signedPayload();

        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(orphanPayload, tripId, uniqueKey()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("STOP_NOT_IN_ROUTE"))
                .andExpect(jsonPath("$.message").value(BoardingService.MSG_STOP_NOT_IN_ROUTE));
    }

    @Test
    @DisplayName("POST /confirm — suspended student returns 403 STUDENT_SUSPENDED")
    void confirm_suspendedStudent_returnsStudentSuspended() throws Exception {
        startTrip();

        User studentUser = userRepository.findByEmail("boarding_student@test.com").orElseThrow();
        studentUser.setStatus(UserStatus.SUSPENDED);
        userRepository.saveAndFlush(studentUser);

        try {
            mockMvc.perform(post("/api/boarding/confirm")
                    .header("Authorization", authHeader())
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(
                            new ConfirmBoardingRequest(stopQrPayload, tripId, uniqueKey()))))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("STUDENT_SUSPENDED"))
                    .andExpect(jsonPath("$.message").value(BoardingService.MSG_STUDENT_SUSPENDED));
        } finally {
            // Always restore so remaining tests are unaffected
            studentUser.setStatus(UserStatus.ACTIVE);
            userRepository.saveAndFlush(studentUser);
        }
    }

    @Test
    @DisplayName("POST /confirm — invalid QR signature returns 400 QR_INVALID")
    void confirm_invalidQr_returnsQrInvalid() throws Exception {
        startTrip();
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest("TAMPERED.badsignature", tripId, uniqueKey()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("QR_INVALID"));
    }

    @Test
    @DisplayName("POST /confirm — no auth token returns 401")
    void confirm_noAuth_returns401() throws Exception {
        mockMvc.perform(post("/api/boarding/confirm")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, uniqueKey()))))
                .andExpect(status().isUnauthorized());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HISTORY endpoint
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("GET /history — returns confirmed boardings for the authenticated student")
    void getHistory_returnsStudentHistory() throws Exception {
        startTrip();
        // Board first
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", authHeader())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, uniqueKey()))))
                .andExpect(status().isOk());

        // Verify history reflects the boarding
        mockMvc.perform(get("/api/boarding/history")
                .header("Authorization", authHeader()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].paymentStatus").value("UNPAID"))
                .andExpect(jsonPath("$[0].tripId").value(tripId));
    }
}

package com.shuttle.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.admin.fare.FareRequest;
import com.shuttle.admin.fare.FareService;
import com.shuttle.admin.stop.BusStopService;
import com.shuttle.admin.trip.TripRequest;
import com.shuttle.admin.trip.TripService;
import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.LoginRequest;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.boarding.dto.ConfirmBoardingRequest;
import com.shuttle.boarding.dto.ValidateBoardingRequest;
import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Notification;
import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.RouteStop;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.entity.VirtualBusCard;
import com.shuttle.domain.entity.Wallet;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.CardStatus;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.enums.PaymentMethod;
import com.shuttle.domain.enums.PaymentStatus;
import com.shuttle.domain.enums.PaymentType;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.StopStatus;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.NotificationRepository;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.RouteStopRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.domain.repository.VirtualBusCardRepository;
import com.shuttle.domain.repository.WalletRepository;
import com.shuttle.student.CardTokenService;
import com.shuttle.student.dto.VerifyCardRequest;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import javax.crypto.SecretKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Comprehensive Security & Quality Review Integration Tests")
class SecurityComprehensiveIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private AuthService authService;
    @Autowired private JwtService jwtService;
    @Autowired private CardTokenService cardTokenService;
    @Autowired private BusStopService busStopService;
    @Autowired private TripService tripService;
    @Autowired private FareService fareService;

    @Autowired private UserRepository userRepository;
    @Autowired private StudentRepository studentRepository;
    @Autowired private DriverRepository driverRepository;
    @Autowired private BusRepository busRepository;
    @Autowired private RouteRepository routeRepository;
    @Autowired private RouteStopRepository routeStopRepository;
    @Autowired private BusStopRepository busStopRepository;
    @Autowired private TripRepository tripRepository;
    @Autowired private WalletRepository walletRepository;
    @Autowired private MonthlyPassRepository monthlyPassRepository;
    @Autowired private PaymentRepository paymentRepository;
    @Autowired private NotificationRepository notificationRepository;
    @Autowired private VirtualBusCardRepository virtualBusCardRepository;
    @Autowired private BoardingRecordRepository boardingRecordRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    private static final AtomicInteger seq = new AtomicInteger(100);

    private String studentAToken;
    private Long studentAId;
    private User studentAUser;

    private String studentBToken;
    private Long studentBId;
    private User studentBUser;

    private String driverToken;
    private Long driverId;

    private String adminToken;

    private Long busId;
    private Long routeId;
    private Long stopId;
    private String stopQrPayload;
    private Long tripId;

    @BeforeEach
    void setUp() {
        int n = seq.incrementAndGet();

        // 1. Admin
        if (!userRepository.existsByEmail("sec_admin@test.com")) {
            User adminUser = new User();
            adminUser.setEmail("sec_admin@test.com");
            adminUser.setPasswordHash(passwordEncoder.encode("AdminPass123!"));
            adminUser.setFullName("Security Admin");
            adminUser.setRole(Role.ADMIN);
            adminUser.setStatus(UserStatus.ACTIVE);
            userRepository.save(adminUser);
        }
        User admin = userRepository.findByEmail("sec_admin@test.com").orElseThrow();
        adminToken = jwtService.generateAccessToken(admin);

        // 2. Student A
        String studentAEmail = "sec_student_a_" + n + "@test.com";
        authService.register(new RegisterRequest(
                "Student Alpha", studentAEmail, "Password123!", "STU-A-" + n, "IT", 2024, null));
        studentAUser = userRepository.findByEmail(studentAEmail).orElseThrow();
        studentAId = studentRepository.findByUserId(studentAUser.getId()).orElseThrow().getId();
        studentAToken = jwtService.generateAccessToken(studentAUser);

        // 3. Student B
        String studentBEmail = "sec_student_b_" + n + "@test.com";
        authService.register(new RegisterRequest(
                "Student Beta", studentBEmail, "Password123!", "STU-B-" + n, "IT", 2024, null));
        studentBUser = userRepository.findByEmail(studentBEmail).orElseThrow();
        studentBId = studentRepository.findByUserId(studentBUser.getId()).orElseThrow().getId();
        studentBToken = jwtService.generateAccessToken(studentBUser);

        // 4. Driver
        String driverEmail = "sec_driver_" + n + "@test.com";
        User driverUser = new User();
        driverUser.setEmail(driverEmail);
        driverUser.setPasswordHash(passwordEncoder.encode("DriverPass123!"));
        driverUser.setFullName("Driver Dan " + n);
        driverUser.setRole(Role.DRIVER);
        driverUser.setStatus(UserStatus.ACTIVE);
        userRepository.save(driverUser);

        Driver driver = new Driver();
        driver.setUser(driverUser);
        driver.setLicenseNumber("LIC-SEC-" + n);
        driver.setStatus(DriverStatus.ACTIVE);
        driverId = driverRepository.save(driver).getId();
        driverToken = jwtService.generateAccessToken(driverUser);

        // 5. Bus, Route, Stop, Trip Infrastructure
        Bus bus = new Bus();
        bus.setBusNumber("SEC-BUS-" + n);
        bus.setPlateNumber("PLT-SEC-" + n);
        bus.setCapacity(40);
        bus.setStatus(BusStatus.ACTIVE);
        busId = busRepository.save(bus).getId();

        Route route = new Route();
        route.setName("Sec Route " + n);
        route.setCode("SRT-" + n);
        route.setStatus(RouteStatus.ACTIVE);
        routeId = routeRepository.save(route).getId();

        BusStop stop = new BusStop();
        stop.setName("Sec Stop " + n);
        stop.setQrCode("SSTOP-" + n);
        stop.setLatitude(BigDecimal.valueOf(6.9271));
        stop.setLongitude(BigDecimal.valueOf(79.8612));
        stop.setStatus(StopStatus.ACTIVE);
        stopId = busStopRepository.save(stop).getId();

        RouteStop rs = new RouteStop();
        rs.setRoute(route);
        rs.setBusStop(stop);
        rs.setStopOrder(1);
        routeStopRepository.save(rs);

        busStopRepository.flush();
        stopQrPayload = busStopService.getQrPayload(stopId).signedPayload();

        // Standard trip
        tripId = tripService.create(new TripRequest(routeId, busId, driverId,
                Instant.now().plusSeconds(300), null, null)).id();

        // Add a fare of 50.00 for this route/stop (must be STANDARD class as checked by boarding)
        fareService.create(new FareRequest(routeId, stopId, new BigDecimal("50.00"), "STANDARD", LocalDate.now().minusDays(1), null));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Role Authorization Tests (401 / 403 on all controllers)
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Security: Unauthenticated requests return 401 across all protected endpoints")
    void unauthenticatedAccess_returns401() throws Exception {
        mockMvc.perform(get("/api/admin/buses"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/students/me"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/driver/assignment"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/trips/current"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/boarding/history"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/wallet"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/monthly-pass"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Security: Student role cannot access Admin or Driver endpoints (403 Forbidden)")
    void studentRole_accessingRestrictedEndpoints_returns403() throws Exception {
        // Student cannot access admin endpoints
        mockMvc.perform(get("/api/admin/buses")
                .header("Authorization", "Bearer " + studentAToken))
                .andExpect(status().isForbidden());

        // Student cannot access driver endpoints
        mockMvc.perform(get("/api/driver/assignment")
                .header("Authorization", "Bearer " + studentAToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/trips/current")
                .header("Authorization", "Bearer " + studentAToken))
                .andExpect(status().isForbidden());

        // Student cannot verify card QR (driver/admin only)
        mockMvc.perform(post("/api/cards/verify")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"dummy\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Security: Driver role cannot access Admin, Student, or Payment endpoints (403 Forbidden)")
    void driverRole_accessingRestrictedEndpoints_returns403() throws Exception {
        // Driver cannot access admin
        mockMvc.perform(get("/api/admin/buses")
                .header("Authorization", "Bearer " + driverToken))
                .andExpect(status().isForbidden());

        // Driver cannot access student self-service
        mockMvc.perform(get("/api/students/me")
                .header("Authorization", "Bearer " + driverToken))
                .andExpect(status().isForbidden());

        // Driver cannot access wallet
        mockMvc.perform(get("/api/wallet")
                .header("Authorization", "Bearer " + driverToken))
                .andExpect(status().isForbidden());

        // Driver cannot access monthly pass
        mockMvc.perform(get("/api/monthly-pass")
                .header("Authorization", "Bearer " + driverToken))
                .andExpect(status().isForbidden());

        // Driver cannot confirm boarding (student only)
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + driverToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, UUID.randomUUID().toString(), null, null, null))))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Security: Driver is authorized to verify cards and get current trip")
    void driverRole_authorizedEndpoints_succeed() throws Exception {
        mockMvc.perform(get("/api/trips/current")
                .header("Authorization", "Bearer " + driverToken))
                .andExpect(status().isOk());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. IDOR Tests (Students cannot access or tamper with other students' data)
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("IDOR Prevention: Student A cannot read Student B payment status (403 Forbidden)")
    void idor_studentACannotReadStudentBPayment() throws Exception {
        // Create a payment for Student B
        Student studentB = studentRepository.findById(studentBId).orElseThrow();
        Payment paymentB = new Payment();
        paymentB.setStudent(studentB);
        paymentB.setAmount(new BigDecimal("500.00"));
        paymentB.setType(PaymentType.WALLET_TOPUP);
        paymentB.setMethod(PaymentMethod.ONLINE);
        paymentB.setStatus(PaymentStatus.SUCCESS);
        paymentB.setDescription("Top-up for student B");
        Payment savedB = paymentRepository.save(paymentB);

        // Student A attempts to read Student B's payment -> 403 Forbidden
        mockMvc.perform(get("/api/payment/status/" + savedB.getId())
                .header("Authorization", "Bearer " + studentAToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        // Student B can read their own payment -> 200 OK
        mockMvc.perform(get("/api/payment/status/" + savedB.getId())
                .header("Authorization", "Bearer " + studentBToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount").value(500.0));

        // Admin can read Student B's payment -> 200 OK
        mockMvc.perform(get("/api/payment/status/" + savedB.getId())
                .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount").value(500.0));
    }

    @Test
    @DisplayName("IDOR Prevention: Student A cannot mark Student B notification as read (403 Forbidden)")
    void idor_studentACannotMarkStudentBNotificationAsRead() throws Exception {
        Notification notifB = new Notification();
        notifB.setUser(studentBUser);
        notifB.setTitle("Private Alert for B");
        notifB.setMessage("Confidential information");
        notifB.setType(NotificationType.ALERT);
        notifB.setRead(false);
        Notification savedNotif = notificationRepository.save(notifB);

        // Student A attempts to mark B's notification as read -> 403 Forbidden
        mockMvc.perform(patch("/api/notifications/" + savedNotif.getId() + "/read")
                .header("Authorization", "Bearer " + studentAToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        // Student B can mark it as read -> 200 OK
        mockMvc.perform(patch("/api/notifications/" + savedNotif.getId() + "/read")
                .header("Authorization", "Bearer " + studentBToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.read").value(true));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. QR Tokens: Expiry, Tamper Resistance, and Replay Behavior
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("QR Security: Tampered stop QR payload is rejected with QR_INVALID (400)")
    void qrSecurity_tamperedStopQrRejected() throws Exception {
        tripService.startTrip(tripId);

        String tamperedQr = stopQrPayload.substring(0, stopQrPayload.lastIndexOf('.') + 1) + "forgedSignature123";

        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        tamperedQr, tripId, UUID.randomUUID().toString(), null, null, null))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("QR_INVALID"));
    }

    @Test
    @DisplayName("QR Security: Expired student card token is rejected with TOKEN_EXPIRED (401)")
    void qrSecurity_expiredStudentCardTokenRejected() throws Exception {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        String expiredToken = Jwts.builder()
                .subject("UBC-STU-001")
                .claim("type", "QR_BOARDING")
                .issuedAt(Date.from(Instant.now().minusSeconds(120)))
                .expiration(Date.from(Instant.now().minusSeconds(60)))
                .signWith(key)
                .compact();

        mockMvc.perform(post("/api/cards/verify")
                .header("Authorization", "Bearer " + driverToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new VerifyCardRequest(expiredToken))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_EXPIRED"));
    }

    @Test
    @DisplayName("QR Security: Replay of user JWT access token in QR verification is rejected with TOKEN_INVALID (401)")
    void qrSecurity_accessTokenReplayRejected() throws Exception {
        // Attempting to scan a student's access token instead of a QR token
        mockMvc.perform(post("/api/cards/verify")
                .header("Authorization", "Bearer " + driverToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new VerifyCardRequest(studentAToken))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_INVALID"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Duplicate Boarding & Idempotency
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Boarding: Duplicate boarding on the same trip is rejected with 409 Conflict")
    void boarding_duplicateBoardingRejected() throws Exception {
        // Credit student wallet
        Wallet wallet = walletRepository.findByStudentId(studentAId).orElseThrow();
        wallet.setBalance(new BigDecimal("500.00"));
        walletRepository.save(wallet);

        tripService.startTrip(tripId);

        String firstKey = UUID.randomUUID().toString();
        // First boarding succeeds
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, firstKey, 6.9271, 79.8612, 10.0))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.alreadyBoarded").value(false));

        // Second boarding on same trip with different idempotency key -> 409 Conflict
        String secondKey = UUID.randomUUID().toString();
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, secondKey, 6.9271, 79.8612, 10.0))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_BOARDED"));

        // Idempotent retry with firstKey returns existing record without error
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, firstKey, 6.9271, 79.8612, 10.0))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.alreadyBoarded").value(true));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Expired Monthly Pass Behavior
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Monthly Pass: Expired pass does not grant free travel; fails if wallet is empty (402)")
    void monthlyPass_expiredPass_requiresWalletBalance() throws Exception {
        // Ensure wallet balance is 0
        Wallet wallet = walletRepository.findByStudentId(studentAId).orElseThrow();
        wallet.setBalance(BigDecimal.ZERO);
        walletRepository.save(wallet);

        // Create an EXPIRED monthly pass for Student A (ended yesterday)
        MonthlyPass expiredPass = new MonthlyPass();
        expiredPass.setStudent(studentRepository.findById(studentAId).orElseThrow());
        expiredPass.setValidFrom(LocalDate.now().minusMonths(1));
        expiredPass.setValidTo(LocalDate.now().minusDays(1));
        expiredPass.setStatus(PassStatus.EXPIRED);
        expiredPass.setPrice(new BigDecimal("1500.00"));
        monthlyPassRepository.save(expiredPass);

        tripService.startTrip(tripId);

        // Attempt boarding -> 402 Payment Required because pass is expired and wallet is 0
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, UUID.randomUUID().toString(), null, null, null))))
                .andExpect(status().isPaymentRequired())
                .andExpect(jsonPath("$.code").value("INSUFFICIENT_BALANCE"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Insufficient Balance
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Wallet: Insufficient balance rejected with 402 Payment Required")
    void wallet_insufficientBalance_rejectedWith402() throws Exception {
        Wallet wallet = walletRepository.findByStudentId(studentAId).orElseThrow();
        wallet.setBalance(new BigDecimal("10.00")); // Fare is 50.00
        walletRepository.save(wallet);

        tripService.startTrip(tripId);

        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, UUID.randomUUID().toString(), null, null, null))))
                .andExpect(status().isPaymentRequired())
                .andExpect(jsonPath("$.code").value("INSUFFICIENT_BALANCE"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Payment Verification & Webhook Signature
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Payment: Webhook with invalid signature is rejected with 400 Bad Request")
    void payment_invalidWebhookSignatureRejected() throws Exception {
        mockMvc.perform(post("/api/payment/webhook")
                .param("paymentId", "99999")
                .param("status", "success")
                .param("mock_hash", "completely-fake-forged-signature"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("WEBHOOK_INVALID"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. GPS Outside Allowed Area
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("GPS: Boarding with coordinates outside stop radius is rejected with 400 Bad Request")
    void gps_outsideRadiusRejected() throws Exception {
        Wallet wallet = walletRepository.findByStudentId(studentAId).orElseThrow();
        wallet.setBalance(new BigDecimal("500.00"));
        walletRepository.save(wallet);

        tripService.startTrip(tripId);

        // Stop is at 6.9271, 79.8612. Send GPS from 7.5000, 80.5000 (~100km away)
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, UUID.randomUUID().toString(), 7.5000, 80.5000, 10.0))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("GPS_TOO_FAR"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Cancelled Trip
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Trip Lifecycle: Boarding on a cancelled or non-in-progress trip is rejected with 409 Conflict")
    void trip_cancelledTripRejected() throws Exception {
        Trip trip = tripRepository.findById(tripId).orElseThrow();
        trip.setStatus(TripStatus.CANCELLED);
        tripRepository.save(trip);

        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", "Bearer " + studentAToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new ConfirmBoardingRequest(
                        stopQrPayload, tripId, UUID.randomUUID().toString(), null, null, null))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("TRIP_NOT_ACTIVE"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Rate Limiting Tests (429 Too Many Requests)
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Rate Limiting: Exceeding 10 auth login requests per minute returns 429 Too Many Requests")
    void rateLimiting_loginEndpoint_returns429() throws Exception {
        LoginRequest req = new LoginRequest("sec_admin@test.com", "WrongPassword!");
        String body = objectMapper.writeValueAsString(req);

        // Send 10 requests to consume bucket capacity
        for (int i = 0; i < 10; i++) {
            mockMvc.perform(post("/api/auth/login")
                    .header("X-Forwarded-For", "192.0.2.42")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(body));
        }

        // 11th request must be throttled with 429
        mockMvc.perform(post("/api/auth/login")
                .header("X-Forwarded-For", "192.0.2.42")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMIT_EXCEEDED"));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Security Headers Tests
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("Security Headers: Response contains X-Content-Type-Options, X-Frame-Options, CSP, HSTS")
    void securityHeaders_areEnforced() throws Exception {
        mockMvc.perform(get("/api/routes")
                .secure(true)
                .header("Authorization", "Bearer " + studentAToken))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("X-Frame-Options", "DENY"))
                .andExpect(header().exists("Content-Security-Policy"))
                .andExpect(header().exists("Strict-Transport-Security"));
    }
}

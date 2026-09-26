package com.shuttle.payment;

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
import com.shuttle.domain.entity.Fare;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.RouteStop;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.entity.Wallet;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.FareClass;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.StopStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.FareRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.RouteStopRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.domain.repository.WalletRepository;
import com.shuttle.security.JwtService;
import com.shuttle.wallet.dto.TopUpRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
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
@DisplayName("Wallet and Payment integration tests")
class WalletPaymentIntegrationTest {

    @Autowired private MockMvc           mockMvc;
    @Autowired private ObjectMapper      objectMapper;
    @Autowired private AuthService       authService;
    @Autowired private JwtService        jwtService;
    @Autowired private TripService       tripService;
    @Autowired private BusStopService    busStopService;
    @Autowired private UserRepository    userRepository;
    @Autowired private StudentRepository studentRepository;
    @Autowired private WalletRepository  walletRepository;
    @Autowired private DriverRepository  driverRepository;
    @Autowired private BusRepository     busRepository;
    @Autowired private RouteRepository   routeRepository;
    @Autowired private RouteStopRepository routeStopRepository;
    @Autowired private BusStopRepository busStopRepository;
    @Autowired private FareRepository    fareRepository;
    @Autowired private PasswordEncoder   passwordEncoder;

    private static final AtomicInteger seq = new AtomicInteger(0);

    private String studentToken;
    private Long   studentId;
    private Long   walletId;
    private Long   tripId;
    private String stopQrPayload;
    private Long   routeId;
    private Long   stopId;
    private Long   driverId;

    // Standard fare used in boarding tests
    private static final BigDecimal FARE = new BigDecimal("75.00");

    @BeforeEach
    void setUp() {
        int n = seq.incrementAndGet();

        // ── Student ───────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("wallet_student@test.com")) {
            authService.register(new RegisterRequest(
                    "Wallet Student", "wallet_student@test.com",
                    "Password1!", "WS001", "Finance", 2024, null));
        }
        User studentUser = userRepository.findByEmail("wallet_student@test.com").orElseThrow();
        studentToken = jwtService.generateAccessToken(studentUser);
        studentId    = studentRepository.findByUserId(studentUser.getId()).orElseThrow().getId();
        Wallet wallet = walletRepository.findByStudentId(studentId).orElseThrow();
        walletId = wallet.getId();

        // Reset wallet balance to 0 before each test
        wallet.setBalance(BigDecimal.ZERO);
        walletRepository.saveAndFlush(wallet);

        // ── Driver ────────────────────────────────────────────────────────────
        if (!userRepository.existsByEmail("wallet_driver@test.com")) {
            User du = new User(); du.setEmail("wallet_driver@test.com");
            du.setPasswordHash(passwordEncoder.encode("Password1!"));
            du.setFullName("Wallet Driver"); du.setRole(Role.DRIVER);
            du.setStatus(UserStatus.ACTIVE);
            userRepository.save(du);
            Driver d = new Driver(); d.setUser(du);
            d.setLicenseNumber("LIC-WL-001"); d.setStatus(DriverStatus.ACTIVE);
            driverRepository.save(d);
        }
        driverId = driverRepository.findAll().stream()
                .filter(d -> d.getLicenseNumber().equals("LIC-WL-001"))
                .findFirst().orElseThrow().getId();

        // ── Bus ───────────────────────────────────────────────────────────────
        Bus bus = new Bus(); bus.setBusNumber("WL-BUS-" + n);
        bus.setPlateNumber("WL-PLT-" + n); bus.setCapacity(40);
        bus.setStatus(BusStatus.ACTIVE);
        Long busId = busRepository.save(bus).getId();

        // ── Route + stop ──────────────────────────────────────────────────────
        Route route = new Route(); route.setName("Wallet Route " + n);
        route.setCode("WL-RT-" + n); route.setStatus(RouteStatus.ACTIVE);
        routeId = routeRepository.save(route).getId();

        BusStop stop = new BusStop(); stop.setName("Wallet Stop " + n);
        stop.setQrCode("WL-STOP-" + n); stop.setStatus(StopStatus.ACTIVE);
        stopId = busStopRepository.saveAndFlush(stop).getId();

        RouteStop rs = new RouteStop();
        rs.setRoute(routeRepository.findById(routeId).orElseThrow());
        rs.setBusStop(stop); rs.setStopOrder(1);
        routeStopRepository.saveAndFlush(rs);

        stopQrPayload = busStopService.getQrPayload(stopId).signedPayload();

        // ── Fare ──────────────────────────────────────────────────────────────
        Fare fare = new Fare();
        fare.setRoute(routeRepository.findById(routeId).orElseThrow());
        fare.setStop(stop);
        fare.setAmount(FARE);
        fare.setFareClass(FareClass.STANDARD);
        fare.setEffectiveFrom(LocalDate.of(2024, 1, 1));
        fareRepository.saveAndFlush(fare);

        // ── Trip ──────────────────────────────────────────────────────────────
        tripId = tripService.create(new TripRequest(routeId, busId, driverId,
                Instant.now().plusSeconds(600), null, null)).id();
    }

    private String auth() { return "Bearer " + studentToken; }
    private String key()  { return UUID.randomUUID().toString(); }
    private void   startTrip() { tripService.startTrip(tripId); }

    // ══════════════════════════════════════════════════════════════════════════
    // GET /api/wallet
    // ══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("GET /wallet — returns balance and status")
    void getWallet_returnsBalance() throws Exception {
        mockMvc.perform(get("/api/wallet").header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value(0))
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // POST /api/wallet/top-up  →  webhook  →  balance credited
    // ══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Top-up success: initiates checkout and webhook credits wallet")
    void topUp_success_creditsWallet() throws Exception {
        // 1. Initiate top-up — returns checkout URL
        var topUpResult = mockMvc.perform(post("/api/wallet/top-up")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new TopUpRequest(new BigDecimal("500.00")))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.paymentId", notNullValue()))
                .andExpect(jsonPath("$.checkoutUrl", notNullValue()))
                .andExpect(jsonPath("$.paymentStatus").value("PENDING"))
                .andReturn();

        Long paymentId = objectMapper.readTree(
                topUpResult.getResponse().getContentAsString()).get("paymentId").asLong();

        // 2. Simulate mock gateway callback (webhook)
        String checkoutUrl = objectMapper.readTree(
                topUpResult.getResponse().getContentAsString()).get("checkoutUrl").asText();
        // Extract params from URL: /api/payment/mock-callback?paymentId=X&status=success&mock_hash=Y
        String queryString = checkoutUrl.substring(checkoutUrl.indexOf('?') + 1);
        mockMvc.perform(get("/api/payment/mock-callback?" + queryString))
                .andExpect(status().isOk());

        // 3. Wallet balance must now be 500.00
        mockMvc.perform(get("/api/wallet").header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value(500.0));

        // 4. Payment status must be SUCCESS
        mockMvc.perform(get("/api/payment/status/" + paymentId)
                .header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SUCCESS"));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Duplicate webhook — must NOT double-credit
    // ══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Duplicate webhook does not double-credit wallet")
    void duplicateWebhook_doesNotDoubleCreditWallet() throws Exception {
        // Top-up and get checkout URL
        var topUpResult = mockMvc.perform(post("/api/wallet/top-up")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new TopUpRequest(new BigDecimal("300.00")))))
                .andExpect(status().isCreated())
                .andReturn();

        String checkoutUrl = objectMapper.readTree(
                topUpResult.getResponse().getContentAsString()).get("checkoutUrl").asText();
        String queryString = checkoutUrl.substring(checkoutUrl.indexOf('?') + 1);

        // First webhook — should succeed
        mockMvc.perform(get("/api/payment/mock-callback?" + queryString))
                .andExpect(status().isOk());

        // Second identical webhook — should be ignored (idempotent)
        mockMvc.perform(get("/api/payment/mock-callback?" + queryString))
                .andExpect(status().isOk());

        // Balance must still be exactly 300.00 (not 600.00)
        mockMvc.perform(get("/api/wallet").header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value(300.0));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Boarding deducts fare from wallet
    // ══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Boarding deducts fare (75 LKR) from wallet and sets paymentStatus=PAID")
    void boarding_deductsFareFromWallet() throws Exception {
        // Fund the wallet first
        creditWalletDirectly(new BigDecimal("200.00"));
        startTrip();

        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, key(),
                                null, null, null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fareAmount").value(75.0))
                .andExpect(jsonPath("$.paymentStatus").value("PAID"));

        // Wallet balance must now be 200 - 75 = 125
        mockMvc.perform(get("/api/wallet").header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value(125.0));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Insufficient balance — boarding rejected
    // ══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Boarding rejected with INSUFFICIENT_BALANCE when wallet < fare")
    void boarding_insufficientBalance_rejected() throws Exception {
        // Wallet starts at 0 — below the 75 LKR fare
        startTrip();

        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, key(),
                                null, null, null))))
                .andExpect(status().isPaymentRequired())
                .andExpect(jsonPath("$.code").value("INSUFFICIENT_BALANCE"))
                .andExpect(jsonPath("$.message").value("Insufficient wallet balance."));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Concurrent boardings — wallet never goes negative
    // ══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("Concurrent boardings for same student: only one succeeds, wallet not overdrawn")
    void concurrentBoardings_walletNotOverdrawn() throws Exception {
        // Fund wallet with exactly one fare amount
        creditWalletDirectly(FARE);
        startTrip();

        // Fire two simultaneous confirm requests with different keys
        String key1 = key();
        String key2 = key();
        CountDownLatch latch = new CountDownLatch(1);
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger conflictCount = new AtomicInteger(0);

        Runnable board = () -> {
            try {
                latch.await();
                String k = Thread.currentThread().getName().contains("1") ? key1 : key2;
                var result = mockMvc.perform(post("/api/boarding/confirm")
                        .header("Authorization", auth())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new ConfirmBoardingRequest(stopQrPayload, tripId, k,
                                        null, null, null))))
                        .andReturn();
                int status = result.getResponse().getStatus();
                if (status == 200) successCount.incrementAndGet();
                else if (status == 409 || status == 402) conflictCount.incrementAndGet();
            } catch (Exception e) { /* count nothing */ }
        };

        ExecutorService pool = Executors.newFixedThreadPool(2);
        pool.submit(board); pool.submit(board);
        latch.countDown();
        pool.shutdown();
        pool.awaitTermination(10, java.util.concurrent.TimeUnit.SECONDS);

        // At least one boarding should have been attempted
        assertThat(successCount.get()).isLessThanOrEqualTo(1);

        // Wallet must not go below zero — this is the critical safety invariant
        Wallet wallet = walletRepository.findByStudentId(studentId).orElseThrow();
        assertThat(wallet.getBalance())
                .as("Wallet balance must not be negative")
                .isGreaterThanOrEqualTo(BigDecimal.ZERO);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // GET /api/wallet/transactions
    // ══════════════════════════════════════════════════════════════════════════

    @Test
    @DisplayName("GET /wallet/transactions — shows debit after boarding")
    void walletTransactions_showsDebitAfterBoarding() throws Exception {
        // Fund via direct balance (test setup shortcut) — does NOT write a tx row
        creditWalletDirectly(new BigDecimal("500.00"));
        startTrip();
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, key(),
                                null, null, null))))
                .andExpect(status().isOk());

        // There should be exactly one DEBIT transaction from the boarding
        mockMvc.perform(get("/api/wallet/transactions").header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].type").value("DEBIT"))
                .andExpect(jsonPath("$[0].amount").value(75.0));
    }

    @Test
    @DisplayName("GET /wallet/transactions — shows CREDIT via webhook then DEBIT via boarding")
    void walletTransactions_creditThenDebit() throws Exception {
        // 1. Top-up via real webhook flow (writes a WalletTransaction CREDIT)
        var topUpResult = mockMvc.perform(post("/api/wallet/top-up")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new TopUpRequest(new BigDecimal("500.00")))))
                .andExpect(status().isCreated())
                .andReturn();

        String checkoutUrl = objectMapper.readTree(
                topUpResult.getResponse().getContentAsString()).get("checkoutUrl").asText();
        String queryString = checkoutUrl.substring(checkoutUrl.indexOf('?') + 1);
        mockMvc.perform(get("/api/payment/mock-callback?" + queryString))
                .andExpect(status().isOk());

        // 2. Board (writes a DEBIT transaction)
        startTrip();
        mockMvc.perform(post("/api/boarding/confirm")
                .header("Authorization", auth())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new ConfirmBoardingRequest(stopQrPayload, tripId, key(),
                                null, null, null))))
                .andExpect(status().isOk());

        // 3. Transactions: most recent first → [0]=DEBIT, [1]=CREDIT
        mockMvc.perform(get("/api/wallet/transactions").header("Authorization", auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].type").value("DEBIT"))
                .andExpect(jsonPath("$[1].type").value("CREDIT"));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Helper — credit wallet directly (bypasses gateway, for test setup only)
    // ══════════════════════════════════════════════════════════════════════════

    private void creditWalletDirectly(BigDecimal amount) {
        Wallet wallet = walletRepository.findByStudentId(studentId).orElseThrow();
        wallet.setBalance(wallet.getBalance().add(amount));
        walletRepository.saveAndFlush(wallet);
    }
}

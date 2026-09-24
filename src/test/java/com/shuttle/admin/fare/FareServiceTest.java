package com.shuttle.admin.fare;

import com.shuttle.auth.AuthService;
import com.shuttle.auth.dto.RegisterRequest;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.enums.FareClass;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.StopStatus;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.FareRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.exception.ApiException;
import java.math.BigDecimal;
import java.time.LocalDate;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("FareService – getCurrentFare tests")
class FareServiceTest {

    @Autowired FareService     fareService;
    @Autowired FareRepository  fareRepository;
    @Autowired RouteRepository routeRepository;
    @Autowired BusStopRepository busStopRepository;

    private Long routeId;
    private Long stopId;

    @BeforeEach
    void setUp() {
        Route route = new Route();
        route.setName("Test Route");
        route.setCode("TEST-RT-" + System.nanoTime());
        route.setStatus(RouteStatus.ACTIVE);
        routeId = routeRepository.save(route).getId();

        BusStop stop = new BusStop();
        stop.setName("Test Stop");
        stop.setQrCode("TEST-STOP-" + System.nanoTime());
        stop.setStatus(StopStatus.ACTIVE);
        stopId = busStopRepository.save(stop).getId();
    }

    // ── getCurrentFare happy path ─────────────────────────────────────────────

    @Test
    @DisplayName("getCurrentFare — returns active open-ended fare")
    void getCurrentFare_active_openEnded() {
        createFare(new BigDecimal("75.00"), LocalDate.of(2024, 1, 1), null);

        FareResponse result = fareService.getCurrentFare(routeId, stopId,
                FareClass.STANDARD, LocalDate.of(2025, 6, 1));

        assertThat(result.amount()).isEqualByComparingTo("75.00");
        assertThat(result.fareClass()).isEqualTo("STANDARD");
    }

    @Test
    @DisplayName("getCurrentFare — returns fare within explicit date window")
    void getCurrentFare_withinWindow() {
        createFare(new BigDecimal("50.00"),
                LocalDate.of(2025, 1, 1), LocalDate.of(2025, 12, 31));

        FareResponse result = fareService.getCurrentFare(routeId, stopId,
                FareClass.STANDARD, LocalDate.of(2025, 6, 15));

        assertThat(result.amount()).isEqualByComparingTo("50.00");
    }

    @Test
    @DisplayName("getCurrentFare — returns fare on effectiveFrom boundary (inclusive)")
    void getCurrentFare_onEffectiveFromBoundary() {
        LocalDate from = LocalDate.of(2025, 3, 1);
        createFare(new BigDecimal("60.00"), from, null);

        FareResponse result = fareService.getCurrentFare(routeId, stopId,
                FareClass.STANDARD, from);

        assertThat(result.amount()).isEqualByComparingTo("60.00");
    }

    @Test
    @DisplayName("getCurrentFare — returns fare on effectiveUntil boundary (inclusive)")
    void getCurrentFare_onEffectiveUntilBoundary() {
        LocalDate until = LocalDate.of(2025, 6, 30);
        createFare(new BigDecimal("45.00"), LocalDate.of(2025, 1, 1), until);

        FareResponse result = fareService.getCurrentFare(routeId, stopId,
                FareClass.STANDARD, until);

        assertThat(result.amount()).isEqualByComparingTo("45.00");
    }

    // ── Expired fare ──────────────────────────────────────────────────────────

    @Test
    @DisplayName("getCurrentFare — expired fare throws FARE_NOT_FOUND")
    void getCurrentFare_expiredFare_throwsFareNotFound() {
        createFare(new BigDecimal("30.00"),
                LocalDate.of(2023, 1, 1), LocalDate.of(2023, 12, 31));

        assertThatThrownBy(() -> fareService.getCurrentFare(routeId, stopId,
                FareClass.STANDARD, LocalDate.of(2025, 1, 1)))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("FARE_NOT_FOUND"));
    }

    @Test
    @DisplayName("getCurrentFare — future fare (not yet effective) throws FARE_NOT_FOUND")
    void getCurrentFare_futureFare_throwsFareNotFound() {
        createFare(new BigDecimal("90.00"),
                LocalDate.of(2030, 1, 1), null);

        assertThatThrownBy(() -> fareService.getCurrentFare(routeId, stopId,
                FareClass.STANDARD, LocalDate.of(2025, 1, 1)))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("FARE_NOT_FOUND"));
    }

    @Test
    @DisplayName("getCurrentFare — no fare configured throws FARE_NOT_FOUND")
    void getCurrentFare_noFare_throwsFareNotFound() {
        assertThatThrownBy(() -> fareService.getCurrentFare(routeId, stopId,
                FareClass.STANDARD, LocalDate.now()))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("FARE_NOT_FOUND"));
    }

    // ── Overlap validation ────────────────────────────────────────────────────

    @Test
    @DisplayName("create fare — overlapping range throws FARE_OVERLAP")
    void createFare_overlapping_throwsFareOverlap() {
        // Existing open-ended fare from 2024-01-01
        FareRequest first = new FareRequest(routeId, stopId,
                new BigDecimal("80.00"), "STANDARD",
                LocalDate.of(2024, 1, 1), null);
        fareService.create(first);

        // Attempt to add another open-ended fare for same route+stop — should overlap
        FareRequest conflict = new FareRequest(routeId, stopId,
                new BigDecimal("90.00"), "STANDARD",
                LocalDate.of(2025, 1, 1), null);

        assertThatThrownBy(() -> fareService.create(conflict))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("FARE_OVERLAP"));
    }

    @Test
    @DisplayName("create fare — non-overlapping date ranges are allowed")
    void createFare_nonOverlapping_succeeds() {
        FareRequest first = new FareRequest(routeId, stopId,
                new BigDecimal("80.00"), "STANDARD",
                LocalDate.of(2024, 1, 1), LocalDate.of(2024, 12, 31));
        fareService.create(first);

        FareRequest second = new FareRequest(routeId, stopId,
                new BigDecimal("90.00"), "STANDARD",
                LocalDate.of(2025, 1, 1), null);
        FareResponse response = fareService.create(second);

        assertThat(response.amount()).isEqualByComparingTo("90.00");
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private void createFare(BigDecimal amount, LocalDate from, LocalDate until) {
        FareRequest req = new FareRequest(routeId, stopId, amount, "STANDARD", from, until);
        fareService.create(req);
    }
}

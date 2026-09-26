package com.shuttle.admin.trip;

import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.exception.ApiException;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("TripService – state machine tests")
class TripStateTransitionTest {

    @Autowired TripService      tripService;
    @Autowired BusRepository    busRepository;
    @Autowired RouteRepository  routeRepository;
    @Autowired DriverRepository driverRepository;
    @Autowired UserRepository   userRepository;
    @Autowired PasswordEncoder  passwordEncoder;

    private Long routeId;
    private Long busId;
    private Long driverId;

    @BeforeEach
    void setUp() {
        Route route = new Route();
        route.setName("State Test Route");
        route.setCode("ST-RT-" + System.nanoTime());
        route.setStatus(RouteStatus.ACTIVE);
        routeId = routeRepository.save(route).getId();

        Bus bus = new Bus();
        bus.setBusNumber("BUS-ST-" + System.nanoTime());
        bus.setPlateNumber("PLT-" + System.nanoTime() % 100000);
        bus.setCapacity(40);
        bus.setStatus(BusStatus.ACTIVE);
        busId = busRepository.save(bus).getId();

        User user = new User();
        user.setEmail("driver-st-" + System.nanoTime() + "@test.com");
        user.setPasswordHash(passwordEncoder.encode("Password1!"));
        user.setFullName("State Test Driver");
        user.setRole(Role.DRIVER);
        user.setStatus(UserStatus.ACTIVE);
        userRepository.save(user);

        Driver driver = new Driver();
        driver.setUser(user);
        driver.setLicenseNumber("LIC-ST-" + System.nanoTime());
        driver.setStatus(DriverStatus.ACTIVE);
        driverId = driverRepository.save(driver).getId();
    }

    // ── Valid transitions ─────────────────────────────────────────────────────

    @Test
    @DisplayName("SCHEDULED → IN_PROGRESS (start) is valid")
    void start_fromScheduled_succeeds() {
        Long id = createTrip();
        TripResponse response = tripService.startTrip(id);
        assertThat(response.status()).isEqualTo("IN_PROGRESS");
        assertThat(response.actualStart()).isNotNull();
    }

    @Test
    @DisplayName("IN_PROGRESS → COMPLETED (complete) is valid")
    void complete_fromInProgress_succeeds() {
        Long id = createTrip();
        tripService.startTrip(id);
        TripResponse response = tripService.completeTrip(id);
        assertThat(response.status()).isEqualTo("COMPLETED");
        assertThat(response.actualEnd()).isNotNull();
    }

    @Test
    @DisplayName("SCHEDULED → CANCELLED (cancel) is valid")
    void cancel_fromScheduled_succeeds() {
        Long id = createTrip();
        TripResponse response = tripService.cancelTrip(id);
        assertThat(response.status()).isEqualTo("CANCELLED");
    }

    @Test
    @DisplayName("IN_PROGRESS → CANCELLED (cancel) is valid")
    void cancel_fromInProgress_succeeds() {
        Long id = createTrip();
        tripService.startTrip(id);
        TripResponse response = tripService.cancelTrip(id);
        assertThat(response.status()).isEqualTo("CANCELLED");
    }

    // ── Invalid transitions ───────────────────────────────────────────────────

    @Test
    @DisplayName("Cannot start an IN_PROGRESS trip (already active)")
    void start_fromInProgress_throwsConflict() {
        Long id = createTrip();
        tripService.startTrip(id);

        assertThatThrownBy(() -> tripService.startTrip(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("INVALID_TRIP_TRANSITION"));
    }

    @Test
    @DisplayName("Cannot start a COMPLETED trip")
    void start_fromCompleted_throwsConflict() {
        Long id = createTrip();
        tripService.startTrip(id);
        tripService.completeTrip(id);

        assertThatThrownBy(() -> tripService.startTrip(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("INVALID_TRIP_TRANSITION"));
    }

    @Test
    @DisplayName("Cannot start a CANCELLED trip")
    void start_fromCancelled_throwsConflict() {
        Long id = createTrip();
        tripService.cancelTrip(id);

        assertThatThrownBy(() -> tripService.startTrip(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("INVALID_TRIP_TRANSITION"));
    }

    @Test
    @DisplayName("Cannot complete a SCHEDULED trip (must be started first)")
    void complete_fromScheduled_throwsConflict() {
        Long id = createTrip();

        assertThatThrownBy(() -> tripService.completeTrip(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("INVALID_TRIP_TRANSITION"));
    }

    @Test
    @DisplayName("Cannot complete an already COMPLETED trip")
    void complete_fromCompleted_throwsConflict() {
        Long id = createTrip();
        tripService.startTrip(id);
        tripService.completeTrip(id);

        assertThatThrownBy(() -> tripService.completeTrip(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("INVALID_TRIP_TRANSITION"));
    }

    @Test
    @DisplayName("Cannot cancel an already COMPLETED trip")
    void cancel_fromCompleted_throwsConflict() {
        Long id = createTrip();
        tripService.startTrip(id);
        tripService.completeTrip(id);

        assertThatThrownBy(() -> tripService.cancelTrip(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("TRIP_ALREADY_COMPLETED"));
    }

    // ── Bus conflict ──────────────────────────────────────────────────────────

    @Test
    @DisplayName("Cannot schedule a second trip on the same active bus")
    void create_busAlreadyActive_throwsConflict() {
        Long id1 = createTrip();
        tripService.startTrip(id1);  // bus is now IN_PROGRESS

        // Attempt to start another trip on the same bus
        assertThatThrownBy(() -> {
            Long id2 = createTrip();
            tripService.startTrip(id2);
        })
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("BUS_ALREADY_ACTIVE"));
    }

    @Test
    @DisplayName("Bus can start a new trip after completing the previous one")
    void create_busFreedAfterComplete_succeeds() {
        Long id1 = createTrip();
        tripService.startTrip(id1);
        tripService.completeTrip(id1);

        Long id2 = createTrip();
        TripResponse response = tripService.startTrip(id2);
        assertThat(response.status()).isEqualTo("IN_PROGRESS");
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private Long createTrip() {
        TripRequest req = new TripRequest(routeId, busId, driverId,
                Instant.now().plusSeconds(3600), null, null);
        return tripService.create(req).id();
    }
}

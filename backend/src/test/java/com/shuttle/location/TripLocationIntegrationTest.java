package com.shuttle.location;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.BusStatus;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BusLocationRepository;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.location.dto.BusLocationUpdateRequest;
import com.shuttle.security.JwtService;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_CLASS)
@DisplayName("Live Bus Location Tracking — Integration Tests")
class TripLocationIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private JwtService jwtService;
    @Autowired private UserRepository userRepository;
    @Autowired private DriverRepository driverRepository;
    @Autowired private StudentRepository studentRepository;
    @Autowired private BusRepository busRepository;
    @Autowired private RouteRepository routeRepository;
    @Autowired private TripRepository tripRepository;
    @Autowired private BusLocationRepository busLocationRepository;
    @Autowired private PasswordEncoder passwordEncoder;

    private String driver1Token;
    private String driver2Token;
    private String studentToken;
    private Driver driver1;
    private Driver driver2;
    private Bus bus;
    private Route route;
    private Trip activeTrip;
    private Trip scheduledTrip;

    @BeforeEach
    @Transactional
    void setUp() {
        String suffix = UUID.randomUUID().toString().substring(0, 6);

        // 1. Driver 1
        User u1 = new User();
        u1.setEmail("driver1_loc_" + suffix + "@test.com");
        u1.setPasswordHash(passwordEncoder.encode("Password1!"));
        u1.setFullName("Driver One");
        u1.setRole(Role.DRIVER);
        u1.setStatus(UserStatus.ACTIVE);
        userRepository.save(u1);

        driver1 = new Driver();
        driver1.setUser(u1);
        driver1.setLicenseNumber("LIC-LOC-1-" + suffix);
        driver1.setStatus(DriverStatus.ACTIVE);
        driverRepository.save(driver1);
        driver1Token = jwtService.generateAccessToken(u1);

        // 2. Driver 2
        User u2 = new User();
        u2.setEmail("driver2_loc_" + suffix + "@test.com");
        u2.setPasswordHash(passwordEncoder.encode("Password1!"));
        u2.setFullName("Driver Two");
        u2.setRole(Role.DRIVER);
        u2.setStatus(UserStatus.ACTIVE);
        userRepository.save(u2);

        driver2 = new Driver();
        driver2.setUser(u2);
        driver2.setLicenseNumber("LIC-LOC-2-" + suffix);
        driver2.setStatus(DriverStatus.ACTIVE);
        driverRepository.save(driver2);
        driver2Token = jwtService.generateAccessToken(u2);

        // 3. Student
        User su = new User();
        su.setEmail("student_loc_" + suffix + "@test.com");
        su.setPasswordHash(passwordEncoder.encode("Password1!"));
        su.setFullName("Student One");
        su.setRole(Role.STUDENT);
        su.setStatus(UserStatus.ACTIVE);
        userRepository.save(su);

        Student s = new Student();
        s.setUser(su);
        s.setStudentId("STU-LOC-" + suffix);
        studentRepository.save(s);
        studentToken = jwtService.generateAccessToken(su);

        // 4. Bus & Route
        bus = new Bus();
        bus.setBusNumber("BUS-LOC-" + suffix);
        bus.setPlateNumber("PLATE-LOC-" + suffix);
        bus.setCapacity(40);
        bus.setStatus(BusStatus.ACTIVE);
        busRepository.save(bus);

        route = new Route();
        route.setName("Campus Loop " + suffix);
        route.setCode("RT-LOC-" + suffix);
        route.setStatus(RouteStatus.ACTIVE);
        routeRepository.save(route);

        // 5. Active Trip (IN_PROGRESS) assigned to driver1
        activeTrip = new Trip();
        activeTrip.setBus(bus);
        activeTrip.setRoute(route);
        activeTrip.setDriver(driver1);
        activeTrip.setStatus(TripStatus.IN_PROGRESS);
        activeTrip.setScheduledStart(Instant.now().minus(10, ChronoUnit.MINUTES));
        activeTrip.setActualStart(Instant.now().minus(5, ChronoUnit.MINUTES));
        tripRepository.save(activeTrip);

        // 6. Scheduled Trip (SCHEDULED) assigned to driver1
        scheduledTrip = new Trip();
        scheduledTrip.setBus(bus);
        scheduledTrip.setRoute(route);
        scheduledTrip.setDriver(driver1);
        scheduledTrip.setStatus(TripStatus.SCHEDULED);
        scheduledTrip.setScheduledStart(Instant.now().plus(2, ChronoUnit.HOURS));
        tripRepository.save(scheduledTrip);
    }

    @Test
    @DisplayName("A student cannot post a location at all (returns 403 Forbidden)")
    void studentCannotPostLocation_returnsForbidden() throws Exception {
        BusLocationUpdateRequest req = new BusLocationUpdateRequest(
                new BigDecimal("6.927079"), new BigDecimal("79.861244"), 90.0, 45.0);

        mockMvc.perform(post("/api/driver/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("A driver cannot post location for a trip that is not theirs (returns 403 Forbidden)")
    void driverCannotPostForAnotherDriversTrip_returnsForbidden() throws Exception {
        BusLocationUpdateRequest req = new BusLocationUpdateRequest(
                new BigDecimal("6.927079"), new BigDecimal("79.861244"), 90.0, 45.0);

        // Driver 2 trying to post to Driver 1's trip
        mockMvc.perform(post("/api/driver/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + driver2Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("A driver cannot post location for a trip that is not ACTIVE (returns 409 Conflict)")
    void driverCannotPostForNonActiveTrip_returnsConflict() throws Exception {
        BusLocationUpdateRequest req = new BusLocationUpdateRequest(
                new BigDecimal("6.927079"), new BigDecimal("79.861244"), 90.0, 45.0);

        mockMvc.perform(post("/api/driver/trips/{tripId}/location", scheduledTrip.getId())
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_TRIP_STATUS"));
    }

    @Test
    @DisplayName("Assigned driver can post location for ACTIVE trip, upserting bus_locations table")
    void assignedDriverPostsLocation_activeTrip_successAndUpsert() throws Exception {
        BusLocationUpdateRequest req1 = new BusLocationUpdateRequest(
                new BigDecimal("6.9270790"), new BigDecimal("79.8612440"), 120.0, 35.5);

        mockMvc.perform(post("/api/driver/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req1)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.busId").value(bus.getId()))
                .andExpect(jsonPath("$.tripId").value(activeTrip.getId()))
                .andExpect(jsonPath("$.latitude").value(6.9270790))
                .andExpect(jsonPath("$.longitude").value(79.8612440))
                .andExpect(jsonPath("$.heading").value(120.0))
                .andExpect(jsonPath("$.speedKmh").value(35.5));

        // Verify exactly one row in bus_locations (upsert pattern)
        assertThat(busLocationRepository.findByBusId(bus.getId())).isPresent();
    }

    @Test
    @DisplayName("Rate limit rejects updates more frequent than every 3 seconds with 429")
    void rateLimitEnforced_subsequentPostWithin3Seconds_returns429() throws Exception {
        BusLocationUpdateRequest req1 = new BusLocationUpdateRequest(
                new BigDecimal("6.927079"), new BigDecimal("79.861244"), 120.0, 35.5);

        // First update -> OK
        mockMvc.perform(post("/api/driver/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req1)))
                .andExpect(status().isOk());

        // Immediate second update -> 429 Too Many Requests
        BusLocationUpdateRequest req2 = new BusLocationUpdateRequest(
                new BigDecimal("6.927100"), new BigDecimal("79.861300"), 125.0, 36.0);

        mockMvc.perform(post("/api/driver/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req2)))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMIT_EXCEEDED"));
    }

    @Test
    @DisplayName("Any authenticated user (e.g. Student) can GET live location for active trip")
    void authenticatedUserCanGetLocation_activeTrip_success() throws Exception {
        BusLocationUpdateRequest req = new BusLocationUpdateRequest(
                new BigDecimal("6.927079"), new BigDecimal("79.861244"), 95.0, 40.0);

        // Driver posts location
        mockMvc.perform(post("/api/driver/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk());

        // Student queries location
        mockMvc.perform(get("/api/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.busId").value(bus.getId()))
                .andExpect(jsonPath("$.latitude").value(6.927079))
                .andExpect(jsonPath("$.longitude").value(79.861244));
    }

    @Test
    @DisplayName("GET /api/trips/{tripId}/location returns 404 when no location is reported yet or trip is not active")
    void getLocation_whenNoLocation_returns404() throws Exception {
        mockMvc.perform(get("/api/trips/{tripId}/location", scheduledTrip.getId())
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("Ending a trip clears the bus_locations row so clients do not see a ghost bus")
    void endTrip_clearsBusLocation() throws Exception {
        // Driver posts location
        BusLocationUpdateRequest req = new BusLocationUpdateRequest(
                new BigDecimal("6.927079"), new BigDecimal("79.861244"), 95.0, 40.0);

        mockMvc.perform(post("/api/driver/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + driver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk());

        assertThat(busLocationRepository.findByBusId(bus.getId())).isPresent();

        // Driver ends trip via POST /api/trips/{tripId}/end
        mockMvc.perform(post("/api/trips/{tripId}/end", activeTrip.getId())
                        .header("Authorization", "Bearer " + driver1Token))
                .andExpect(status().isOk());

        // Location row should be cleared/deleted
        assertThat(busLocationRepository.findByBusId(bus.getId())).isEmpty();

        // Subsequent GET location returns 404
        mockMvc.perform(get("/api/trips/{tripId}/location", activeTrip.getId())
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isNotFound());
    }
}

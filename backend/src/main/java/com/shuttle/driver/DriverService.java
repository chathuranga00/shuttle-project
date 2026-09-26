package com.shuttle.driver;

import com.shuttle.admin.trip.TripResponse;
import com.shuttle.domain.entity.Admin;
import com.shuttle.domain.entity.BoardingRecord;
import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.DriverBusAssignment;
import com.shuttle.domain.entity.EmergencyReport;
import com.shuttle.domain.entity.Notification;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.RouteStop;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.repository.AdminRepository;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.domain.repository.DriverBusAssignmentRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.EmergencyReportRepository;
import com.shuttle.domain.repository.NotificationRepository;
import com.shuttle.domain.repository.RouteStopRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.location.BusLocationService;
import com.shuttle.driver.dto.BoardingItemResponse;
import com.shuttle.driver.dto.DriverAssignmentResponse;
import com.shuttle.driver.dto.DriverTripHistoryItem;
import com.shuttle.driver.dto.EmergencyReportRequest;
import com.shuttle.driver.dto.EmergencyReportResponse;
import com.shuttle.driver.dto.TripSummaryResponse;
import com.shuttle.exception.ApiException;
import jakarta.persistence.EntityNotFoundException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DriverService {

    private final TripRepository                tripRepository;
    private final DriverRepository              driverRepository;
    private final UserRepository                userRepository;
    private final BoardingRecordRepository      boardingRecordRepository;
    private final DriverBusAssignmentRepository assignmentRepository;
    private final RouteStopRepository           routeStopRepository;
    private final EmergencyReportRepository     emergencyReportRepository;
    private final NotificationRepository        notificationRepository;
    private final AdminRepository               adminRepository;
    private final BusLocationService            busLocationService;

    /**
     * Resolves the Driver entity from the authenticated principal.
     */
    public Driver resolveDriver(Authentication auth) {
        User user = userRepository.findByEmail(auth.getName())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "User not found."));
        return driverRepository.findByUserId(user.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "DRIVER_NOT_FOUND", "Driver profile not found."));
    }

    /**
     * GET /api/trips/current
     * Returns the driver's active trip (IN_PROGRESS) or scheduled trip for today.
     */
    @Transactional(readOnly = true)
    public TripResponse getCurrentTrip(Authentication auth) {
        Driver driver = resolveDriver(auth);

        // 1. Check for any active trip in progress
        List<Trip> activeTrips = tripRepository.findByDriverIdAndStatus(driver.getId(), TripStatus.IN_PROGRESS);
        if (!activeTrips.isEmpty()) {
            return toTripResponse(activeTrips.get(0));
        }

        // 2. Check for scheduled trip for today (UTC window)
        Instant startOfDayUtc = LocalDate.now(ZoneOffset.UTC).atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant endOfDayUtc   = LocalDate.now(ZoneOffset.UTC).plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        List<Trip> scheduledToday = tripRepository
                .findByDriverIdAndStatusAndScheduledStartBetweenOrderByScheduledStartAsc(
                        driver.getId(), TripStatus.SCHEDULED, startOfDayUtc, endOfDayUtc);

        if (!scheduledToday.isEmpty()) {
            return toTripResponse(scheduledToday.get(0));
        }

        // 3. Fallback: check scheduled trips using local system timezone window
        Instant startOfDayLocal = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant();
        Instant endOfDayLocal   = LocalDate.now().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant();

        List<Trip> scheduledLocal = tripRepository
                .findByDriverIdAndStatusAndScheduledStartBetweenOrderByScheduledStartAsc(
                        driver.getId(), TripStatus.SCHEDULED, startOfDayLocal, endOfDayLocal);

        if (!scheduledLocal.isEmpty()) {
            return toTripResponse(scheduledLocal.get(0));
        }

        throw new ApiException(HttpStatus.NOT_FOUND, "NO_CURRENT_TRIP", "No assigned trip found for today.");
    }

    /**
     * POST /api/trips/{id}/start
     * Driver starts their assigned trip (SCHEDULED → IN_PROGRESS).
     */
    @Transactional
    public TripResponse startTrip(Long tripId, Authentication auth) {
        Driver driver = resolveDriver(auth);
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new EntityNotFoundException("Trip " + tripId + " not found."));

        if (!trip.getDriver().getId().equals(driver.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN",
                    "You are not authorized to start a trip assigned to another driver.");
        }

        if (trip.getStatus() != TripStatus.SCHEDULED) {
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_TRIP_TRANSITION",
                    "Cannot start a trip with status " + trip.getStatus() + ". Required: SCHEDULED.");
        }

        // Ensure bus is not already running another active trip
        tripRepository.findActiveTripsByBus(trip.getBus().getId())
                .stream()
                .filter(t -> !t.getId().equals(tripId))
                .findAny()
                .ifPresent(t -> {
                    throw new ApiException(HttpStatus.CONFLICT, "BUS_ALREADY_ACTIVE",
                            "Bus is already running trip " + t.getId() + ".");
                });

        trip.setStatus(TripStatus.IN_PROGRESS);
        trip.setActualStart(Instant.now());
        return toTripResponse(tripRepository.save(trip));
    }

    /**
     * POST /api/trips/{id}/end
     * Driver ends their assigned trip (IN_PROGRESS → COMPLETED).
     */
    @Transactional
    public TripResponse endTrip(Long tripId, Authentication auth) {
        Driver driver = resolveDriver(auth);
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new EntityNotFoundException("Trip " + tripId + " not found."));

        if (!trip.getDriver().getId().equals(driver.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN",
                    "You are not authorized to end a trip assigned to another driver.");
        }

        if (trip.getStatus() != TripStatus.IN_PROGRESS) {
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_TRIP_TRANSITION",
                    "End is only allowed for ACTIVE trips. Current status: " + trip.getStatus() + ".");
        }

        trip.setStatus(TripStatus.COMPLETED);
        trip.setActualEnd(Instant.now());
        Trip saved = tripRepository.save(trip);

        // Clear bus location so clients do not see a ghost bus
        busLocationService.clearLocationForTrip(trip.getId(), trip.getBus() != null ? trip.getBus().getId() : null);

        return toTripResponse(saved);
    }

    /**
     * GET /api/driver/trips/{id}/summary
     * Summary: total passengers, monthly pass count, pay-per-trip count, and recent boardings.
     */
    @Transactional(readOnly = true)
    public TripSummaryResponse getTripSummary(Long tripId, Authentication auth) {
        Driver driver = resolveDriver(auth);
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new EntityNotFoundException("Trip " + tripId + " not found."));

        if (!trip.getDriver().getId().equals(driver.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN",
                    "You can only view trip summaries for your own assigned trips.");
        }

        List<BoardingRecord> boardings = boardingRecordRepository.findByTripId(tripId);

        long totalPassengers = boardings.size();
        long monthlyPassCount = boardings.stream()
                .filter(r -> r.getMonthlyPass() != null || "PASS".equalsIgnoreCase(r.getPaymentStatus()))
                .count();
        long payPerTripCount = totalPassengers - monthlyPassCount;

        List<BoardingItemResponse> recent = boardings.stream()
                .sorted((a, b) -> b.getBoardedAt().compareTo(a.getBoardedAt()))
                .map(r -> new BoardingItemResponse(
                        r.getId(),
                        r.getStudent().getId(),
                        r.getStudent().getUser().getFullName(),
                        r.getBusStop().getName(),
                        r.getBoardedAt(),
                        r.getFareAmount(),
                        r.getPaymentStatus()))
                .collect(Collectors.toList());

        return new TripSummaryResponse(trip.getId(), totalPassengers, monthlyPassCount, payPerTripCount, recent);
    }

    /**
     * POST /api/driver/emergency-report
     * Stores emergency report and creates admin notifications.
     */
    @Transactional
    public EmergencyReportResponse reportEmergency(EmergencyReportRequest req, Authentication auth) {
        Driver driver = resolveDriver(auth);

        Trip trip = null;
        if (req.tripId() != null) {
            trip = tripRepository.findById(req.tripId())
                    .orElseThrow(() -> new EntityNotFoundException("Trip " + req.tripId() + " not found."));
            if (!trip.getDriver().getId().equals(driver.getId())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN",
                        "You can only associate an emergency with your own assigned trip.");
            }
        } else {
            // Auto-associate active trip if one exists
            List<Trip> active = tripRepository.findByDriverIdAndStatus(driver.getId(), TripStatus.IN_PROGRESS);
            if (!active.isEmpty()) {
                trip = active.get(0);
            }
        }

        EmergencyReport report = new EmergencyReport();
        report.setDriver(driver);
        report.setTrip(trip);
        report.setType(req.type());
        report.setDescription(req.description());
        report.setLocation(req.location());
        report.setStatus("REPORTED");
        report = emergencyReportRepository.save(report);

        // Notify admins
        List<User> adminUsers = userRepository.findByRole(Role.ADMIN);
        if (adminUsers.isEmpty()) {
            adminUsers = adminRepository.findAll().stream().map(Admin::getUser).collect(Collectors.toList());
        }

        for (User admin : adminUsers) {
            Notification notif = new Notification();
            notif.setUser(admin);
            notif.setTitle("EMERGENCY ALERT: " + req.type());
            String loc = (req.location() != null && !req.location().isBlank()) ? " at " + req.location() : "";
            notif.setMessage("Driver " + driver.getUser().getFullName() + " reported: " + req.description() + loc);
            notif.setType(NotificationType.ALERT);
            notif.setRead(false);
            notificationRepository.save(notif);
        }

        return new EmergencyReportResponse(
                report.getId(),
                driver.getId(),
                driver.getUser().getFullName(),
                trip != null ? trip.getId() : null,
                report.getType(),
                report.getDescription(),
                report.getLocation(),
                report.getStatus(),
                report.getCreatedAt());
    }

    /**
     * GET /api/driver/trips/history
     * Returns past and completed trips for the driver.
     */
    @Transactional(readOnly = true)
    public List<DriverTripHistoryItem> getTripHistory(Authentication auth) {
        Driver driver = resolveDriver(auth);
        List<Trip> trips = tripRepository.findByDriverIdOrderByScheduledStartDesc(driver.getId());

        List<DriverTripHistoryItem> result = new ArrayList<>();
        for (Trip t : trips) {
            List<BoardingRecord> records = boardingRecordRepository.findByTripId(t.getId());
            int total = records.size();
            int passCount = (int) records.stream()
                    .filter(r -> r.getMonthlyPass() != null || "PASS".equalsIgnoreCase(r.getPaymentStatus()))
                    .count();
            int payPerTrip = total - passCount;

            result.add(new DriverTripHistoryItem(
                    t.getId(),
                    t.getRoute().getId(),
                    t.getRoute().getName(),
                    t.getBus().getId(),
                    t.getBus().getBusNumber(),
                    t.getStatus().name(),
                    t.getScheduledStart(),
                    t.getScheduledEnd(),
                    t.getActualStart(),
                    t.getActualEnd(),
                    total,
                    passCount,
                    payPerTrip,
                    t.getNotes(),
                    t.getCreatedAt()));
        }
        return result;
    }

    /**
     * GET /api/driver/assignment
     * Returns currently assigned bus and route with stops.
     */
    @Transactional(readOnly = true)
    public DriverAssignmentResponse getAssignment(Authentication auth) {
        Driver driver = resolveDriver(auth);
        Optional<DriverBusAssignment> current = assignmentRepository.findCurrentByDriverId(driver.getId());

        DriverAssignmentResponse.DriverBusDto busDto = null;
        DriverAssignmentResponse.DriverRouteDto routeDto = null;

        if (current.isPresent()) {
            Bus bus = current.get().getBus();
            if (bus != null) {
                busDto = new DriverAssignmentResponse.DriverBusDto(
                        bus.getId(),
                        bus.getBusNumber(),
                        bus.getPlateNumber(),
                        bus.getCapacity(),
                        bus.getStatus().name());
            }

            Route route = current.get().getRoute();
            if (route != null) {
                List<RouteStop> stops = routeStopRepository.findByRouteIdOrderByStopOrderAsc(route.getId());
                List<DriverAssignmentResponse.DriverStopDto> stopDtos = stops.stream()
                        .map(rs -> new DriverAssignmentResponse.DriverStopDto(
                                rs.getBusStop().getId(),
                                rs.getBusStop().getName(),
                                rs.getBusStop().getQrCode(),
                                rs.getStopOrder(),
                                rs.getBusStop().getLatitude() != null ? rs.getBusStop().getLatitude().doubleValue() : null,
                                rs.getBusStop().getLongitude() != null ? rs.getBusStop().getLongitude().doubleValue() : null))
                        .collect(Collectors.toList());

                routeDto = new DriverAssignmentResponse.DriverRouteDto(
                        route.getId(),
                        route.getName(),
                        route.getCode(),
                        route.getDescription(),
                        route.getEstimatedDurationMinutes(),
                        route.getStatus().name(),
                        stopDtos);
            }
        }

        return new DriverAssignmentResponse(
                driver.getId(),
                driver.getUser().getFullName(),
                driver.getLicenseNumber(),
                driver.getStatus().name(),
                busDto,
                routeDto);
    }

    private TripResponse toTripResponse(Trip t) {
        return new TripResponse(
                t.getId(),
                t.getRoute().getId(),
                t.getRoute().getName(),
                t.getBus().getId(),
                t.getBus().getBusNumber(),
                t.getDriver().getId(),
                t.getDriver().getUser().getFullName(),
                t.getStatus().name(),
                t.getScheduledStart(),
                t.getScheduledEnd(),
                t.getActualStart(),
                t.getActualEnd(),
                t.getNotes(),
                t.getCreatedAt(),
                t.getUpdatedAt());
    }
}

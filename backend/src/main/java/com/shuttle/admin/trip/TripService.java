package com.shuttle.admin.trip;

import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.exception.ApiException;
import jakarta.persistence.EntityNotFoundException;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.shuttle.domain.enums.NotificationType;
import com.shuttle.notification.NotificationService;
import com.shuttle.notification.dto.AnnouncementRequest;

@Service
@RequiredArgsConstructor
public class TripService {

    private final TripRepository   tripRepository;
    private final RouteRepository  routeRepository;
    private final BusRepository    busRepository;
    private final DriverRepository driverRepository;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<TripResponse> listAll() {
        return tripRepository.findAll().stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public TripResponse getById(Long id) {
        return toResponse(load(id));
    }

    @Transactional
    public TripResponse create(TripRequest req) {
        // A bus cannot have two active (IN_PROGRESS) trips simultaneously
        if (!tripRepository.findActiveTripsByBus(req.busId()).isEmpty()) {
            throw new ApiException(HttpStatus.CONFLICT, "BUS_ALREADY_ACTIVE",
                    "Bus " + req.busId() + " already has an active trip.");
        }
        Route  route  = loadRoute(req.routeId());
        Bus    bus    = loadBus(req.busId());
        Driver driver = loadDriver(req.driverId());

        Trip trip = new Trip();
        trip.setRoute(route);
        trip.setBus(bus);
        trip.setDriver(driver);
        trip.setStatus(TripStatus.SCHEDULED);
        trip.setScheduledStart(req.scheduledStart());
        trip.setScheduledEnd(req.scheduledEnd());
        trip.setNotes(req.notes());
        return toResponse(tripRepository.save(trip));
    }

    @Transactional
    public TripResponse update(Long id, TripRequest req) {
        Trip trip = load(id);
        if (trip.getStatus() == TripStatus.COMPLETED || trip.getStatus() == TripStatus.CANCELLED) {
            throw new ApiException(HttpStatus.CONFLICT, "TRIP_TERMINAL",
                    "Cannot modify a trip that is " + trip.getStatus() + ".");
        }
        // If changing bus, check the new bus is not already active
        if (!trip.getBus().getId().equals(req.busId())) {
            if (!tripRepository.findActiveTripsByBus(req.busId()).isEmpty()) {
                throw new ApiException(HttpStatus.CONFLICT, "BUS_ALREADY_ACTIVE",
                        "Bus " + req.busId() + " already has an active trip.");
            }
        }
        trip.setRoute(loadRoute(req.routeId()));
        trip.setBus(loadBus(req.busId()));
        trip.setDriver(loadDriver(req.driverId()));
        trip.setScheduledStart(req.scheduledStart());
        trip.setScheduledEnd(req.scheduledEnd());
        trip.setNotes(req.notes());
        return toResponse(tripRepository.save(trip));
    }

    // ── State transitions ─────────────────────────────────────────────────────

    /**
     * SCHEDULED → IN_PROGRESS
     * Validates: cannot start a completed/cancelled/already-active trip.
     */
    @Transactional
    public TripResponse startTrip(Long id) {
        Trip trip = load(id);
        assertStatus(trip, TripStatus.SCHEDULED, "start");
        // Ensure bus is not already running another trip
        tripRepository.findActiveTripsByBus(trip.getBus().getId())
                .stream()
                .filter(t -> !t.getId().equals(id))
                .findAny()
                .ifPresent(t -> {
                    throw new ApiException(HttpStatus.CONFLICT, "BUS_ALREADY_ACTIVE",
                            "Bus is already running trip " + t.getId() + ".");
                });
        trip.setStatus(TripStatus.IN_PROGRESS);
        trip.setActualStart(Instant.now());
        return toResponse(tripRepository.save(trip));
    }

    /**
     * IN_PROGRESS → COMPLETED
     */
    @Transactional
    public TripResponse completeTrip(Long id) {
        Trip trip = load(id);
        assertStatus(trip, TripStatus.IN_PROGRESS, "complete");
        trip.setStatus(TripStatus.COMPLETED);
        trip.setActualEnd(Instant.now());
        return toResponse(tripRepository.save(trip));
    }

    /**
     * SCHEDULED or IN_PROGRESS → CANCELLED
     */
    @Transactional
    public TripResponse cancelTrip(Long id) {
        Trip trip = load(id);
        if (trip.getStatus() == TripStatus.COMPLETED) {
            throw new ApiException(HttpStatus.CONFLICT, "TRIP_ALREADY_COMPLETED",
                    "Cannot cancel a completed trip.");
        }
        if (trip.getStatus() == TripStatus.CANCELLED) {
            throw new ApiException(HttpStatus.CONFLICT, "TRIP_ALREADY_CANCELLED",
                    "Trip is already cancelled.");
        }
        trip.setStatus(TripStatus.CANCELLED);
        Trip saved = tripRepository.save(trip);

        String routeName = trip.getRoute() != null ? trip.getRoute().getName() : "Shuttle Route";
        String cancelMsg = "Trip #" + trip.getId() + " on route " + routeName + " has been cancelled.";

        if (trip.getDriver() != null && trip.getDriver().getUser() != null) {
            notificationService.createNotification(
                    trip.getDriver().getUser(),
                    "Trip Cancelled",
                    cancelMsg,
                    NotificationType.TRIP_UPDATE
            );
        }

        try {
            notificationService.sendAnnouncement(new AnnouncementRequest("Trip Cancelled", cancelMsg, "STUDENT"));
        } catch (Exception e) {
            // Ignore if announcement has no active students
        }

        return toResponse(saved);
    }

    @Transactional
    public void deleteTrip(Long id) {
        Trip trip = load(id);
        tripRepository.delete(trip);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    Trip load(Long id) {
        return tripRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Trip " + id + " not found."));
    }

    private void assertStatus(Trip trip, TripStatus required, String action) {
        if (trip.getStatus() != required) {
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_TRIP_TRANSITION",
                    "Cannot " + action + " a trip with status " + trip.getStatus()
                    + ". Required: " + required + ".");
        }
    }

    private Route  loadRoute(Long id)  {
        return routeRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Route " + id + " not found."));
    }
    private Bus    loadBus(Long id)    {
        return busRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Bus " + id + " not found."));
    }
    private Driver loadDriver(Long id) {
        return driverRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Driver " + id + " not found."));
    }

    TripResponse toResponse(Trip t) {
        return new TripResponse(
                t.getId(),
                t.getRoute().getId(),  t.getRoute().getName(),
                t.getBus().getId(),    t.getBus().getBusNumber(),
                t.getDriver().getId(), t.getDriver().getUser().getFullName(),
                t.getStatus().name(),
                t.getScheduledStart(), t.getScheduledEnd(),
                t.getActualStart(),    t.getActualEnd(),
                t.getNotes(),
                t.getCreatedAt(),      t.getUpdatedAt());
    }
}

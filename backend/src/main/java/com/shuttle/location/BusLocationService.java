package com.shuttle.location;

import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.BusLocation;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.repository.BusLocationRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.location.dto.BusLocationResponse;
import com.shuttle.location.dto.BusLocationUpdateRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class BusLocationService {

    private final BusLocationRepository busLocationRepository;
    private final TripRepository tripRepository;
    private final DriverRepository driverRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;

    // Rate-limiting map: tripId -> last update timestamp
    private final Map<Long, Instant> lastUpdatePerTrip = new ConcurrentHashMap<>();
    private static final long RATE_LIMIT_MILLIS = 3000; // 3 seconds

    /**
     * Resolves the Driver entity from the authenticated principal.
     */
    public Driver resolveDriver(Authentication auth) {
        if (auth == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Authentication required.");
        }
        User user = userRepository.findByEmail(auth.getName())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "User not found."));
        return driverRepository.findByUserId(user.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "NOT_A_DRIVER", "User is not a registered driver."));
    }

    /**
     * POST /api/driver/trips/{tripId}/location
     * DRIVER role only, must be assigned driver, trip must be ACTIVE (IN_PROGRESS).
     * Rate-limited to max 1 update per 3 seconds.
     */
    @Transactional
    public BusLocationResponse updateLocation(Long tripId, BusLocationUpdateRequest req, Authentication auth) {
        Driver driver = resolveDriver(auth);

        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "TRIP_NOT_FOUND", "Trip " + tripId + " not found."));

        // Driver must be assigned to this trip
        if (!trip.getDriver().getId().equals(driver.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN",
                    "You are not assigned to trip " + tripId + ".");
        }

        // Trip must be ACTIVE (IN_PROGRESS)
        if (trip.getStatus() != TripStatus.IN_PROGRESS) {
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_TRIP_STATUS",
                    "Trip must be IN_PROGRESS to post location. Current status: " + trip.getStatus());
        }

        // Rate-limiting: updates cannot be more frequent than every 3 seconds
        Instant now = Instant.now();
        Instant last = lastUpdatePerTrip.get(tripId);
        if (last != null && Duration.between(last, now).toMillis() < RATE_LIMIT_MILLIS) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMIT_EXCEEDED",
                    "Location updates cannot be more frequent than every 3 seconds.");
        }
        lastUpdatePerTrip.put(tripId, now);

        Bus bus = trip.getBus();

        // Upsert current location per bus
        BusLocation location = busLocationRepository.findByBusId(bus.getId())
                .orElseGet(() -> new BusLocation(bus, trip, req.getLatitude(), req.getLongitude(), req.getHeading(), req.getEffectiveSpeedKmh()));

        location.setTrip(trip);
        location.setLatitude(req.getLatitude());
        location.setLongitude(req.getLongitude());
        location.setHeading(req.getHeading());
        location.setSpeedKmh(req.getEffectiveSpeedKmh());

        BusLocation saved = busLocationRepository.save(location);

        BusLocationResponse response = toResponse(saved);

        // Broadcast to trip-specific WebSocket topic and global locations topic
        try {
            messagingTemplate.convertAndSend("/topic/trips/" + tripId + "/location", response);
            messagingTemplate.convertAndSend("/topic/trips/locations", response);
        } catch (Exception e) {
            log.warn("Failed to broadcast WebSocket location for trip {}: {}", tripId, e.getMessage());
        }

        return response;
    }

    /**
     * GET /api/trips/{tripId}/location
     * Returns current bus location for trip or 404 if not available.
     */
    @Transactional(readOnly = true)
    public BusLocationResponse getLocation(Long tripId) {
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "TRIP_NOT_FOUND", "Trip " + tripId + " not found."));

        if (trip.getStatus() != TripStatus.IN_PROGRESS) {
            throw new ApiException(HttpStatus.NOT_FOUND, "LOCATION_NOT_FOUND",
                    "Trip " + tripId + " is not active (" + trip.getStatus() + "). No live location available.");
        }

        BusLocation location = busLocationRepository.findByTripId(tripId)
                .orElseGet(() -> busLocationRepository.findByBusId(trip.getBus().getId())
                        .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "LOCATION_NOT_FOUND",
                                "No location reported yet for trip " + tripId + ".")));

        return toResponse(location);
    }

    /**
     * Clears or marks stale the bus_locations row when a trip ends or is cancelled.
     */
    @Transactional
    public void clearLocationForTrip(Long tripId, Long busId) {
        lastUpdatePerTrip.remove(tripId);

        if (tripId != null) {
            busLocationRepository.deleteByTripId(tripId);
        }
        if (busId != null) {
            busLocationRepository.deleteByBusId(busId);
        }

        BusLocationResponse clearedResponse = BusLocationResponse.builder()
                .tripId(tripId)
                .busId(busId)
                .cleared(true)
                .updatedAt(Instant.now())
                .build();

        try {
            if (tripId != null) {
                messagingTemplate.convertAndSend("/topic/trips/" + tripId + "/location", clearedResponse);
            }
            messagingTemplate.convertAndSend("/topic/trips/locations", clearedResponse);
        } catch (Exception e) {
            log.warn("Failed to broadcast cleared location event for trip {}: {}", tripId, e.getMessage());
        }
    }

    /**
     * GET /api/admin/trips/locations
     * Returns all currently active bus locations for the admin live map.
     */
    @Transactional(readOnly = true)
    public List<BusLocationResponse> getAllActiveLocations() {
        return busLocationRepository.findAllActiveBusLocations().stream()
                .filter(bl -> bl.getTrip() != null && bl.getTrip().getStatus() == TripStatus.IN_PROGRESS)
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * GET /api/trips/active
     * Returns list of all currently active (IN_PROGRESS) trips.
     */
    @Transactional(readOnly = true)
    public List<com.shuttle.location.dto.ActiveTripResponse> getActiveTrips() {
        return tripRepository.findByStatus(TripStatus.IN_PROGRESS).stream()
                .map(t -> com.shuttle.location.dto.ActiveTripResponse.builder()
                        .tripId(t.getId())
                        .routeId(t.getRoute() != null ? t.getRoute().getId() : null)
                        .routeName(t.getRoute() != null ? t.getRoute().getName() : "Unknown Route")
                        .routeCode(t.getRoute() != null ? t.getRoute().getCode() : "")
                        .busId(t.getBus() != null ? t.getBus().getId() : null)
                        .busNumber(t.getBus() != null ? t.getBus().getBusNumber() : "")
                        .status(t.getStatus().name())
                        .actualStart(t.getActualStart())
                        .build())
                .collect(Collectors.toList());
    }

    private BusLocationResponse toResponse(BusLocation loc) {
        return BusLocationResponse.builder()
                .id(loc.getId())
                .busId(loc.getBus().getId())
                .busNumber(loc.getBus().getBusNumber())
                .tripId(loc.getTrip() != null ? loc.getTrip().getId() : null)
                .latitude(loc.getLatitude())
                .longitude(loc.getLongitude())
                .heading(loc.getHeading())
                .speedKmh(loc.getSpeedKmh())
                .updatedAt(loc.getUpdatedAt())
                .cleared(false)
                .build();
    }
}

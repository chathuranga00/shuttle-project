package com.shuttle.admin.fare;

import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Fare;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.enums.FareClass;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.FareRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.exception.ApiException;
import jakarta.persistence.EntityNotFoundException;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class FareService {

    private final FareRepository  fareRepository;
    private final RouteRepository routeRepository;
    private final BusStopRepository busStopRepository;

    @Transactional(readOnly = true)
    public List<FareResponse> listByRoute(Long routeId) {
        return fareRepository.findByRouteId(routeId).stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public FareResponse getById(Long id) {
        return toResponse(load(id));
    }

    @Transactional
    public FareResponse create(FareRequest req) {
        validate(req, null);
        Fare fare = new Fare();
        apply(fare, req);
        return toResponse(fareRepository.save(fare));
    }

    @Transactional
    public FareResponse update(Long id, FareRequest req) {
        Fare fare = load(id);
        validate(req, id);
        apply(fare, req);
        return toResponse(fareRepository.save(fare));
    }

    @Transactional
    public void delete(Long id) {
        fareRepository.delete(load(id));
    }

    /**
     * Returns the single active STANDARD-class fare for a route+stop on today's date.
     * Throws {@code 404 FARE_NOT_FOUND} if none is configured.
     */
    @Transactional(readOnly = true)
    public FareResponse getCurrentFare(Long routeId, Long stopId) {
        return getCurrentFare(routeId, stopId, FareClass.STANDARD, LocalDate.now());
    }

    /**
     * Returns the active fare for a route+stop+fareClass on a given date.
     * Use this overload in tests that need clock control.
     */
    @Transactional(readOnly = true)
    public FareResponse getCurrentFare(Long routeId, Long stopId,
                                       FareClass fareClass, LocalDate date) {
        return fareRepository.findActiveFare(routeId, stopId, fareClass, date)
                .map(this::toResponse)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "FARE_NOT_FOUND",
                        "No active " + fareClass + " fare found for route " + routeId
                        + " at stop " + stopId + " on " + date + "."));
    }

    // ── Package-visible helpers ───────────────────────────────────────────────

    /** Returns the current fare amount for UI display, or null if not found. */
    @Transactional(readOnly = true)
    public Optional<Fare> findCurrentFareEntity(Long routeId, Long stopId) {
        return fareRepository.findActiveFare(routeId, stopId,
                FareClass.STANDARD, LocalDate.now());
    }

    FareResponse toResponse(Fare fare) {
        return new FareResponse(
                fare.getId(),
                fare.getRoute().getId(),
                fare.getRoute().getName(),
                fare.getStop().getId(),
                fare.getStop().getName(),
                fare.getAmount(),
                fare.getFareClass().name(),
                fare.getEffectiveFrom(),
                fare.getEffectiveUntil(),
                fare.getCreatedAt());
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private void validate(FareRequest req, Long excludeId) {
        if (req.effectiveUntil() != null && !req.effectiveUntil().isAfter(req.effectiveFrom())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATE_RANGE",
                    "effectiveUntil must be after effectiveFrom.");
        }
        FareClass fareClass = FareClass.valueOf(req.fareClass().toUpperCase());
        Long exId = excludeId != null ? excludeId : -1L;
        LocalDate until = req.effectiveUntil() != null ? req.effectiveUntil()
                : LocalDate.of(9999, 12, 31);
        if (fareRepository.existsOverlappingFare(req.routeId(), req.stopId(),
                fareClass, exId, req.effectiveFrom(), until)) {
            throw new ApiException(HttpStatus.CONFLICT, "FARE_OVERLAP",
                    "A fare for this route/stop/class already exists in the specified date range.");
        }
    }

    private void apply(Fare fare, FareRequest req) {
        Route route = routeRepository.findById(req.routeId())
                .orElseThrow(() -> new EntityNotFoundException("Route " + req.routeId() + " not found."));
        BusStop stop = busStopRepository.findById(req.stopId())
                .orElseThrow(() -> new EntityNotFoundException("Bus stop " + req.stopId() + " not found."));
        fare.setRoute(route);
        fare.setStop(stop);
        fare.setAmount(req.amount());
        fare.setFareClass(FareClass.valueOf(req.fareClass().toUpperCase()));
        fare.setEffectiveFrom(req.effectiveFrom());
        fare.setEffectiveUntil(req.effectiveUntil());
    }

    private Fare load(Long id) {
        return fareRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Fare " + id + " not found."));
    }
}

package com.shuttle.admin.route;

import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.RouteStop;
import com.shuttle.domain.enums.RouteStatus;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.RouteStopRepository;
import com.shuttle.exception.ApiException;
import jakarta.persistence.EntityNotFoundException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.shuttle.notification.NotificationService;
import com.shuttle.notification.dto.AnnouncementRequest;

@Service
@RequiredArgsConstructor
public class RouteService {

    private final RouteRepository     routeRepository;
    private final RouteStopRepository routeStopRepository;
    private final BusStopRepository   busStopRepository;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<RouteResponse> listAll() {
        return routeRepository.findAll().stream()
                .map(r -> toResponse(r, loadStopDetails(r.getId())))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public RouteResponse getById(Long id) {
        Route route = load(id);
        return toResponse(route, loadStopDetails(id));
    }

    @Transactional
    public RouteResponse create(RouteRequest req) {
        if (routeRepository.existsByCode(req.code())) {
            throw new ApiException(HttpStatus.CONFLICT, "ROUTE_CODE_EXISTS",
                    "Route code '" + req.code() + "' is already in use.");
        }
        validateStops(req.stops(), null);
        Route route = new Route();
        applyBasic(route, req);
        routeRepository.save(route);
        List<RouteStopDetail> details = persistStops(route, req.stops());
        return toResponse(route, details);
    }

    @Transactional
    public RouteResponse update(Long id, RouteRequest req) {
        Route route = load(id);
        if (!route.getCode().equals(req.code()) && routeRepository.existsByCode(req.code())) {
            throw new ApiException(HttpStatus.CONFLICT, "ROUTE_CODE_EXISTS",
                    "Route code '" + req.code() + "' is already in use.");
        }
        validateStops(req.stops(), id);
        applyBasic(route, req);
        routeStopRepository.deleteByRouteId(id);
        List<RouteStopDetail> details = persistStops(route, req.stops());
        Route saved = routeRepository.save(route);
        try {
            notificationService.sendAnnouncement(new AnnouncementRequest(
                    "Route Updated",
                    "Route " + saved.getName() + " (" + saved.getCode() + ") details have been updated.",
                    "ALL"
            ));
        } catch (Exception e) {
            // Non-critical if no recipients
        }
        return toResponse(saved, details);
    }

    @Transactional
    public void delete(Long id) {
        Route route = load(id);
        routeStopRepository.deleteByRouteId(id);
        routeRepository.delete(route);
    }

    // ── Package-visible helpers used by public controller ─────────────────────

    public Route load(Long id) {
        return routeRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Route " + id + " not found."));
    }

    public List<RouteStopDetail> loadStopDetails(Long routeId) {
        return routeStopRepository.findByRouteIdOrderByStopOrderAsc(routeId).stream()
                .map(rs -> {
                    BusStop bs = rs.getBusStop();
                    return new RouteStopDetail(
                            rs.getId(), rs.getStopOrder(), rs.getEstimatedOffsetMinutes(),
                            bs.getId(), bs.getName(), bs.getQrCode(),
                            bs.getLatitude(), bs.getLongitude(), bs.getAddress(),
                            bs.getStatus().name());
                })
                .collect(Collectors.toList());
    }

    RouteResponse toResponse(Route route, List<RouteStopDetail> stops) {
        return new RouteResponse(
                route.getId(), route.getName(), route.getCode(),
                route.getDescription(), route.getEstimatedDurationMinutes(),
                route.getStatus().name(), stops,
                route.getCreatedAt(), route.getUpdatedAt());
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private void applyBasic(Route route, RouteRequest req) {
        route.setName(req.name());
        route.setCode(req.code().toUpperCase().trim());
        route.setDescription(req.description());
        route.setEstimatedDurationMinutes(req.estimatedDurationMinutes());
        route.setStatus(RouteStatus.valueOf(req.status().toUpperCase()));
    }

    /**
     * Validates that:
     * 1. No stop appears twice in the list.
     * 2. stop_order values are unique.
     * 3. Each busStopId resolves to a real stop.
     */
    private void validateStops(List<RouteStopEntry> entries, Long routeId) {
        Set<Long> stopIds   = new HashSet<>();
        Set<Integer> orders = new HashSet<>();
        for (RouteStopEntry entry : entries) {
            if (!stopIds.add(entry.busStopId())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "DUPLICATE_STOP",
                        "Stop " + entry.busStopId() + " appears more than once in the route.");
            }
            if (!orders.add(entry.stopOrder())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "DUPLICATE_STOP_ORDER",
                        "Stop order " + entry.stopOrder() + " is used more than once.");
            }
            if (!busStopRepository.existsById(entry.busStopId())) {
                throw new EntityNotFoundException("Bus stop " + entry.busStopId() + " not found.");
            }
        }
    }

    private List<RouteStopDetail> persistStops(Route route, List<RouteStopEntry> entries) {
        List<RouteStopDetail> details = new ArrayList<>();
        for (RouteStopEntry entry : entries) {
            BusStop busStop = busStopRepository.findById(entry.busStopId()).orElseThrow();
            RouteStop rs = new RouteStop();
            rs.setRoute(route);
            rs.setBusStop(busStop);
            rs.setStopOrder(entry.stopOrder());
            rs.setEstimatedOffsetMinutes(entry.estimatedOffsetMinutes());
            RouteStop saved = routeStopRepository.save(rs);
            details.add(new RouteStopDetail(
                    saved.getId(), saved.getStopOrder(), saved.getEstimatedOffsetMinutes(),
                    busStop.getId(), busStop.getName(), busStop.getQrCode(),
                    busStop.getLatitude(), busStop.getLongitude(), busStop.getAddress(),
                    busStop.getStatus().name()));
        }
        return details;
    }
}

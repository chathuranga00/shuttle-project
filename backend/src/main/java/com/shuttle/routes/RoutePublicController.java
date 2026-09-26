package com.shuttle.routes;

import com.shuttle.admin.fare.FareService;
import com.shuttle.admin.route.RouteResponse;
import com.shuttle.admin.route.RouteService;
import com.shuttle.admin.route.RouteStopDetail;
import com.shuttle.domain.entity.Fare;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/routes")
@RequiredArgsConstructor
@Tag(name = "Routes", description = "Public (authenticated) route information")
@SecurityRequirement(name = "bearerAuth")
public class RoutePublicController {

    private final RouteService routeService;
    private final FareService  fareService;

    @GetMapping
    @Operation(summary = "List all active routes (without stops)")
    public List<RouteResponse> listRoutes() {
        return routeService.listAll();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a route by ID (with stops, without fares)")
    public RouteResponse getRoute(@PathVariable Long id) {
        return routeService.getById(id);
    }

    @GetMapping("/{id}/stops")
    @Operation(summary = "Get all stops for a route, each including the current active fare")
    public List<RouteStopWithFare> getRouteStops(@PathVariable Long id) {
        // Load route (validates it exists)
        routeService.load(id);
        List<RouteStopDetail> stops = routeService.loadStopDetails(id);

        return stops.stream()
                .map(stop -> {
                    Optional<Fare> fare = fareService.findCurrentFareEntity(id, stop.busStopId());
                    return new RouteStopWithFare(
                            stop.routeStopId(),
                            stop.stopOrder(),
                            stop.estimatedOffsetMinutes(),
                            stop.busStopId(),
                            stop.stopName(),
                            stop.qrCode(),
                            stop.latitude(),
                            stop.longitude(),
                            stop.address(),
                            stop.stopStatus(),
                            fare.map(Fare::getAmount).orElse(null));
                })
                .collect(Collectors.toList());
    }
}

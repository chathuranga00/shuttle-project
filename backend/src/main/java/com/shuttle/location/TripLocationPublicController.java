package com.shuttle.location;

import com.shuttle.location.dto.BusLocationResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/trips")
@RequiredArgsConstructor
@Tag(name = "Trip Location", description = "Query live bus location for active trips")
@SecurityRequirement(name = "bearerAuth")
public class TripLocationPublicController {

    private final BusLocationService busLocationService;

    @GetMapping("/{tripId}/location")
    @Operation(summary = "Get live bus location for trip", description = "Returns the current bus location for an active trip. Available to any authenticated user.")
    public ResponseEntity<BusLocationResponse> getLocation(@PathVariable Long tripId) {
        return ResponseEntity.ok(busLocationService.getLocation(tripId));
    }

    @GetMapping("/active")
    @Operation(summary = "Get all active trips", description = "Returns all currently active trips for live map tracking. Available to any authenticated user.")
    public ResponseEntity<java.util.List<com.shuttle.location.dto.ActiveTripResponse>> getActiveTrips() {
        return ResponseEntity.ok(busLocationService.getActiveTrips());
    }
}

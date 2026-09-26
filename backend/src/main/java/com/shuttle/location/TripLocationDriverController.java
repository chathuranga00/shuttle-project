package com.shuttle.location;

import com.shuttle.location.dto.BusLocationResponse;
import com.shuttle.location.dto.BusLocationUpdateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/driver/trips")
@RequiredArgsConstructor
@Tag(name = "Driver Trip Location", description = "Endpoints for driver location sharing during active trips")
@SecurityRequirement(name = "bearerAuth")
public class TripLocationDriverController {

    private final BusLocationService busLocationService;

    @PostMapping("/{tripId}/location")
    @PreAuthorize("hasRole('DRIVER')")
    @Operation(summary = "Post bus location", description = "Updates current bus location. Driver role only, must be assigned to this active trip. Rate limited to max 1 update per 3s.")
    public ResponseEntity<BusLocationResponse> postLocation(
            @PathVariable Long tripId,
            @Valid @RequestBody BusLocationUpdateRequest req,
            Authentication auth) {
        return ResponseEntity.ok(busLocationService.updateLocation(tripId, req, auth));
    }
}

package com.shuttle.location;

import com.shuttle.location.dto.BusLocationResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/trips")
@RequiredArgsConstructor
@Tag(name = "Admin Trip Locations", description = "Query all active bus locations for admin live map")
@SecurityRequirement(name = "bearerAuth")
public class TripLocationAdminController {

    private final BusLocationService busLocationService;

    @GetMapping("/locations")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Get all active bus locations", description = "Returns live locations for all currently active trips on the system.")
    public ResponseEntity<List<BusLocationResponse>> getActiveLocations() {
        return ResponseEntity.ok(busLocationService.getAllActiveLocations());
    }
}

package com.shuttle.driver;

import com.shuttle.admin.trip.TripResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/trips")
@RequiredArgsConstructor
@Tag(name = "Driver – Trips", description = "Driver trip lifecycle controls")
@SecurityRequirement(name = "bearerAuth")
public class TripDriverController {

    private final DriverService driverService;

    @GetMapping("/current")
    @Operation(summary = "Get current assigned trip for today (active or next scheduled)")
    public TripResponse getCurrentTrip(Authentication auth) {
        return driverService.getCurrentTrip(auth);
    }

    @PostMapping("/{id}/start")
    @Operation(summary = "Start assigned trip (SCHEDULED → IN_PROGRESS)")
    public TripResponse startTrip(@PathVariable Long id, Authentication auth) {
        return driverService.startTrip(id, auth);
    }

    @PostMapping("/{id}/end")
    @Operation(summary = "End assigned trip (IN_PROGRESS → COMPLETED)")
    public TripResponse endTrip(@PathVariable Long id, Authentication auth) {
        return driverService.endTrip(id, auth);
    }
}

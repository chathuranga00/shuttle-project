package com.shuttle.driver;

import com.shuttle.driver.dto.DriverAssignmentResponse;
import com.shuttle.driver.dto.DriverTripHistoryItem;
import com.shuttle.driver.dto.EmergencyReportRequest;
import com.shuttle.driver.dto.EmergencyReportResponse;
import com.shuttle.driver.dto.TripSummaryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/driver")
@RequiredArgsConstructor
@Tag(name = "Driver – Portal", description = "Driver trip summary, emergency report, and history")
@SecurityRequirement(name = "bearerAuth")
public class DriverController {

    private final DriverService driverService;

    @GetMapping("/trips/{id}/summary")
    @Operation(summary = "Get trip summary (passenger count, split, recent boardings)")
    public TripSummaryResponse getTripSummary(@PathVariable Long id, Authentication auth) {
        return driverService.getTripSummary(id, auth);
    }

    @PostMapping("/emergency-report")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Submit an emergency report (accident, breakdown, medical, etc.)")
    public EmergencyReportResponse reportEmergency(
            @Valid @RequestBody EmergencyReportRequest request,
            Authentication auth) {
        return driverService.reportEmergency(request, auth);
    }

    @GetMapping("/trips/history")
    @Operation(summary = "Get trip history for authenticated driver")
    public List<DriverTripHistoryItem> getTripHistory(Authentication auth) {
        return driverService.getTripHistory(auth);
    }

    @GetMapping("/assignment")
    @Operation(summary = "Get currently assigned bus and route with stops")
    public DriverAssignmentResponse getAssignment(Authentication auth) {
        return driverService.getAssignment(auth);
    }
}

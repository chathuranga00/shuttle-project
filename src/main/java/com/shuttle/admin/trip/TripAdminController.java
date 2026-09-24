package com.shuttle.admin.trip;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/trips")
@RequiredArgsConstructor
@Tag(name = "Admin – Trips", description = "Trip management and state transitions")
@SecurityRequirement(name = "bearerAuth")
public class TripAdminController {

    private final TripService tripService;

    @GetMapping
    @Operation(summary = "List all trips")
    public List<TripResponse> listAll() { return tripService.listAll(); }

    @GetMapping("/{id}")
    @Operation(summary = "Get trip by ID")
    public TripResponse getById(@PathVariable Long id) { return tripService.getById(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create (schedule) a new trip")
    public TripResponse create(@Valid @RequestBody TripRequest request) {
        return tripService.create(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a trip (while SCHEDULED or IN_PROGRESS)")
    public TripResponse update(@PathVariable Long id, @Valid @RequestBody TripRequest request) {
        return tripService.update(id, request);
    }

    @PostMapping("/{id}/start")
    @Operation(summary = "Start a trip (SCHEDULED → IN_PROGRESS)")
    public TripResponse start(@PathVariable Long id) { return tripService.startTrip(id); }

    @PostMapping("/{id}/complete")
    @Operation(summary = "Complete a trip (IN_PROGRESS → COMPLETED)")
    public TripResponse complete(@PathVariable Long id) { return tripService.completeTrip(id); }

    @PostMapping("/{id}/cancel")
    @Operation(summary = "Cancel a trip (SCHEDULED or IN_PROGRESS → CANCELLED)")
    public TripResponse cancel(@PathVariable Long id) { return tripService.cancelTrip(id); }
}

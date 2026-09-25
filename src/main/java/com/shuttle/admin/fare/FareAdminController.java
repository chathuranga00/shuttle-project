package com.shuttle.admin.fare;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/fares")
@RequiredArgsConstructor
@Tag(name = "Admin – Fares", description = "Fare management")
@SecurityRequirement(name = "bearerAuth")
public class FareAdminController {

    private final FareService fareService;

    @GetMapping
    @Operation(summary = "List fares (optionally filtered by route)")
    public List<FareResponse> listByRoute(@RequestParam(required = false) Long routeId) {
        return fareService.listByRoute(routeId);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get fare by ID")
    public FareResponse getById(@PathVariable Long id) { return fareService.getById(id); }

    @GetMapping("/current")
    @Operation(summary = "Get the current active STANDARD fare for a route+stop")
    public FareResponse getCurrent(@RequestParam Long routeId, @RequestParam Long stopId) {
        return fareService.getCurrentFare(routeId, stopId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a new fare")
    public FareResponse create(@Valid @RequestBody FareRequest request) {
        return fareService.create(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a fare")
    public FareResponse update(@PathVariable Long id, @Valid @RequestBody FareRequest request) {
        return fareService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a fare")
    public void delete(@PathVariable Long id) { fareService.delete(id); }
}

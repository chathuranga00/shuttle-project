package com.shuttle.admin.route;

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
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/routes")
@RequiredArgsConstructor
@Tag(name = "Admin – Routes", description = "Route management")
@SecurityRequirement(name = "bearerAuth")
public class RouteAdminController {

    private final RouteService routeService;

    @GetMapping
    @Operation(summary = "List all routes with stops")
    public List<RouteResponse> listAll() { return routeService.listAll(); }

    @GetMapping("/{id}")
    @Operation(summary = "Get route by ID")
    public RouteResponse getById(@PathVariable Long id) { return routeService.getById(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a new route with ordered stops")
    public RouteResponse create(@Valid @RequestBody RouteRequest request) {
        return routeService.create(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a route and replace its stops")
    public RouteResponse update(@PathVariable Long id, @Valid @RequestBody RouteRequest request) {
        return routeService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a route and its stops")
    public void delete(@PathVariable Long id) { routeService.delete(id); }
}

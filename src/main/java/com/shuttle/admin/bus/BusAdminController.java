package com.shuttle.admin.bus;

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
@RequestMapping("/api/admin/buses")
@RequiredArgsConstructor
@Tag(name = "Admin – Buses", description = "Bus fleet management")
@SecurityRequirement(name = "bearerAuth")
public class BusAdminController {

    private final BusService busService;

    @GetMapping
    @Operation(summary = "List all buses")
    public List<BusResponse> listAll() { return busService.listAll(); }

    @GetMapping("/{id}")
    @Operation(summary = "Get bus by ID")
    public BusResponse getById(@PathVariable Long id) { return busService.getById(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Register a new bus")
    public BusResponse create(@Valid @RequestBody BusRequest request) {
        return busService.create(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a bus")
    public BusResponse update(@PathVariable Long id, @Valid @RequestBody BusRequest request) {
        return busService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a bus")
    public void delete(@PathVariable Long id) { busService.delete(id); }
}

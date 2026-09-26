package com.shuttle.admin.driver;

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
@RequestMapping("/api/admin/drivers")
@RequiredArgsConstructor
@Tag(name = "Admin – Drivers", description = "Driver management")
@SecurityRequirement(name = "bearerAuth")
public class DriverAdminController {

    private final DriverAdminService driverAdminService;

    @GetMapping
    @Operation(summary = "List all drivers")
    public List<DriverResponse> listAll() { return driverAdminService.listAll(); }

    @GetMapping("/{id}")
    @Operation(summary = "Get driver by ID")
    public DriverResponse getById(@PathVariable Long id) { return driverAdminService.getById(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a new driver (user + profile, optional bus/route assignment)")
    public DriverResponse create(@Valid @RequestBody CreateDriverRequest request) {
        return driverAdminService.create(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update driver license and status")
    public DriverResponse update(@PathVariable Long id, @Valid @RequestBody UpdateDriverRequest request) {
        return driverAdminService.update(id, request);
    }

    @PostMapping("/{id}/assign")
    @Operation(summary = "Assign driver to a bus (and optionally a route)")
    public DriverResponse assign(@PathVariable Long id, @Valid @RequestBody AssignDriverRequest request) {
        return driverAdminService.assign(id, request);
    }

    @DeleteMapping("/{id}/assign")
    @Operation(summary = "Remove the driver's current bus/route assignment")
    public DriverResponse unassign(@PathVariable Long id) {
        return driverAdminService.unassign(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete / deactivate driver")
    public void delete(@PathVariable Long id) {
        driverAdminService.delete(id);
    }
}

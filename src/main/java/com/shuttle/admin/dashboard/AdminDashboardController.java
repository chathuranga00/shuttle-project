package com.shuttle.admin.dashboard;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/dashboard")
@RequiredArgsConstructor
@Tag(name = "Admin – Dashboard", description = "High-level system KPIs and operational status")
@SecurityRequirement(name = "bearerAuth")
public class AdminDashboardController {

    private final AdminDashboardService dashboardService;

    @GetMapping
    @Operation(summary = "Get admin dashboard KPI metrics")
    public AdminDashboardResponse getDashboard() {
        return dashboardService.getDashboardStats();
    }
}

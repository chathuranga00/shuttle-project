package com.shuttle.admin.dashboard;

import java.math.BigDecimal;

public record AdminDashboardResponse(
        long totalStudents,
        long totalDrivers,
        long totalBuses,
        long activeTrips,
        long todayPassengers,
        BigDecimal todayRevenue,
        long activeMonthlyPasses,
        long totalRoutes,
        long totalStops
) {}

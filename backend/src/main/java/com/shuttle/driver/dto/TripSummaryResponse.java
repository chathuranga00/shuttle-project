package com.shuttle.driver.dto;

import java.util.List;

public record TripSummaryResponse(
        Long                       tripId,
        long                       totalPassengers,
        long                       monthlyPassCount,
        long                       payPerTripCount,
        List<BoardingItemResponse> recentBoardings
) {}

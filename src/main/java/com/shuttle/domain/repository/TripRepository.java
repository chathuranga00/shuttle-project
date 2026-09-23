package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.enums.TripStatus;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TripRepository extends JpaRepository<Trip, Long> {
    List<Trip> findByStatus(TripStatus status);
    List<Trip> findByRouteId(Long routeId);
}

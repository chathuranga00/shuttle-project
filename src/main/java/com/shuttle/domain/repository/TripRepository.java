package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.enums.TripStatus;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TripRepository extends JpaRepository<Trip, Long> {

    List<Trip> findByStatus(TripStatus status);

    List<Trip> findByRouteId(Long routeId);

    List<Trip> findByDriverId(Long driverId);

    /** Check if the given bus has any trip in a specific status. */
    boolean existsByBusIdAndStatus(Long busId, TripStatus status);

    /** Check if the given driver has any trip in a specific status. */
    boolean existsByDriverIdAndStatus(Long driverId, TripStatus status);

    /** All active (IN_PROGRESS) trips for a bus — used to prevent double-booking. */
    @Query("SELECT t FROM Trip t WHERE t.bus.id = :busId AND t.status = 'IN_PROGRESS'")
    List<Trip> findActiveTripsByBus(@Param("busId") Long busId);
}

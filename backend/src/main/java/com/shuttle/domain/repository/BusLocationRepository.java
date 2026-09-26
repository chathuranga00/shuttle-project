package com.shuttle.domain.repository;

import com.shuttle.domain.entity.BusLocation;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BusLocationRepository extends JpaRepository<BusLocation, Long> {

    Optional<BusLocation> findByBusId(Long busId);

    Optional<BusLocation> findByTripId(Long tripId);

    @Modifying
    @Query("DELETE FROM BusLocation bl WHERE bl.bus.id = :busId")
    void deleteByBusId(@Param("busId") Long busId);

    @Modifying
    @Query("DELETE FROM BusLocation bl WHERE bl.trip.id = :tripId")
    void deleteByTripId(@Param("tripId") Long tripId);

    @Query("SELECT bl FROM BusLocation bl JOIN FETCH bl.bus LEFT JOIN FETCH bl.trip WHERE bl.trip IS NOT NULL")
    List<BusLocation> findAllActiveBusLocations();
}

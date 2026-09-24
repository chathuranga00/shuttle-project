package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Fare;
import com.shuttle.domain.enums.FareClass;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FareRepository extends JpaRepository<Fare, Long> {

    List<Fare> findByRouteId(Long routeId);

    List<Fare> findByRouteIdAndStopId(Long routeId, Long stopId);

    /**
     * Find the single fare active on a given date for a route + stop + class.
     * "Active" means effectiveFrom <= date AND (effectiveUntil IS NULL OR effectiveUntil >= date).
     */
    @Query("""
            SELECT f FROM Fare f
            WHERE f.route.id    = :routeId
              AND f.stop.id     = :stopId
              AND f.fareClass   = :fareClass
              AND f.effectiveFrom <= :date
              AND (f.effectiveUntil IS NULL OR f.effectiveUntil >= :date)
            ORDER BY f.effectiveFrom DESC
            """)
    Optional<Fare> findActiveFare(
            @Param("routeId")   Long routeId,
            @Param("stopId")    Long stopId,
            @Param("fareClass") FareClass fareClass,
            @Param("date")      LocalDate date);

    /**
     * Check for any overlapping active fare for route + stop + class.
     * Used to enforce "only one active fare per route+stop at a time".
     */
    @Query("""
            SELECT COUNT(f) > 0 FROM Fare f
            WHERE f.route.id    = :routeId
              AND f.stop.id     = :stopId
              AND f.fareClass   = :fareClass
              AND f.id         <> :excludeId
              AND f.effectiveFrom <= :until
              AND (f.effectiveUntil IS NULL OR f.effectiveUntil >= :from)
            """)
    boolean existsOverlappingFare(
            @Param("routeId")   Long routeId,
            @Param("stopId")    Long stopId,
            @Param("fareClass") FareClass fareClass,
            @Param("excludeId") Long excludeId,
            @Param("from")      LocalDate from,
            @Param("until")     LocalDate until);
}

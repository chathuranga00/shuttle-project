package com.shuttle.domain.repository;

import com.shuttle.domain.entity.RouteStop;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RouteStopRepository extends JpaRepository<RouteStop, Long> {

    List<RouteStop> findByRouteIdOrderByStopOrderAsc(Long routeId);

    boolean existsByRouteIdAndBusStopId(Long routeId, Long busStopId);

    boolean existsByRouteIdAndBusStopIdAndIdNot(Long routeId, Long busStopId, Long excludeId);

    Optional<RouteStop> findByRouteIdAndBusStopId(Long routeId, Long busStopId);

    void deleteByRouteId(Long routeId);
}

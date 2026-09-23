package com.shuttle.domain.repository;

import com.shuttle.domain.entity.RouteStop;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RouteStopRepository extends JpaRepository<RouteStop, Long> {
    List<RouteStop> findByRouteIdOrderByStopOrderAsc(Long routeId);
}

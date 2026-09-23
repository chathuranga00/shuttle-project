package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Fare;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FareRepository extends JpaRepository<Fare, Long> {
    List<Fare> findByRouteId(Long routeId);
}

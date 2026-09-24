package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Route;
import com.shuttle.domain.enums.RouteStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RouteRepository extends JpaRepository<Route, Long> {

    Optional<Route> findByCode(String code);

    boolean existsByCode(String code);

    List<Route> findByStatus(RouteStatus status);
}

package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Route;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RouteRepository extends JpaRepository<Route, Long> {
    Optional<Route> findByCode(String code);
}

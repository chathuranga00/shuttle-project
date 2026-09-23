package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Bus;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusRepository extends JpaRepository<Bus, Long> {
    Optional<Bus> findByBusNumber(String busNumber);
    Optional<Bus> findByPlateNumber(String plateNumber);
}

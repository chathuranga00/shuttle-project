package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.enums.BusStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusRepository extends JpaRepository<Bus, Long> {

    Optional<Bus> findByBusNumber(String busNumber);

    Optional<Bus> findByPlateNumber(String plateNumber);

    boolean existsByBusNumberAndIdNot(String busNumber, Long id);

    boolean existsByPlateNumberAndIdNot(String plateNumber, Long id);

    List<Bus> findByStatus(BusStatus status);
}

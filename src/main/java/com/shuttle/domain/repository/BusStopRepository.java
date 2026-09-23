package com.shuttle.domain.repository;

import com.shuttle.domain.entity.BusStop;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusStopRepository extends JpaRepository<BusStop, Long> {
    Optional<BusStop> findByQrCode(String qrCode);
    boolean existsByQrCode(String qrCode);
}

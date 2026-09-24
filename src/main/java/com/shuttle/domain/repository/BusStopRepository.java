package com.shuttle.domain.repository;

import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.enums.StopStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusStopRepository extends JpaRepository<BusStop, Long> {

    Optional<BusStop> findByQrCode(String qrCode);

    boolean existsByQrCode(String qrCode);

    boolean existsByQrCodeAndIdNot(String qrCode, Long id);

    List<BusStop> findByStatus(StopStatus status);
}

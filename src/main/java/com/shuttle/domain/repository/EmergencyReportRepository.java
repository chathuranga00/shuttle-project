package com.shuttle.domain.repository;

import com.shuttle.domain.entity.EmergencyReport;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EmergencyReportRepository extends JpaRepository<EmergencyReport, Long> {
    List<EmergencyReport> findByDriverIdOrderByCreatedAtDesc(Long driverId);
}

package com.shuttle.domain.repository;

import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.enums.PassStatus;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MonthlyPassRepository extends JpaRepository<MonthlyPass, Long> {
    List<MonthlyPass> findByStudentId(Long studentId);
    List<MonthlyPass> findByStudentIdAndStatus(Long studentId, PassStatus status);
}

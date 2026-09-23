package com.shuttle.domain.repository;

import com.shuttle.domain.entity.BoardingRecord;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BoardingRecordRepository extends JpaRepository<BoardingRecord, Long> {
    Optional<BoardingRecord> findByTripIdAndStudentId(Long tripId, Long studentId);
    boolean existsByTripIdAndStudentId(Long tripId, Long studentId);
    List<BoardingRecord> findByTripId(Long tripId);
}

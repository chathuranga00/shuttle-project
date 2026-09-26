package com.shuttle.domain.repository;

import com.shuttle.domain.entity.BoardingRecord;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BoardingRecordRepository extends JpaRepository<BoardingRecord, Long> {

    Optional<BoardingRecord> findByTripIdAndStudentId(Long tripId, Long studentId);

    boolean existsByTripIdAndStudentId(Long tripId, Long studentId);

    List<BoardingRecord> findByTripId(Long tripId);

    Optional<BoardingRecord> findByIdempotencyKey(String idempotencyKey);

    long countByBoardedAtBetween(java.time.Instant start, java.time.Instant end);

    List<BoardingRecord> findByBoardedAtBetween(java.time.Instant start, java.time.Instant end);

    List<BoardingRecord> findByBoardedAtBetweenOrderByBoardedAtDesc(java.time.Instant start, java.time.Instant end);

    /** Boarding history for a student, most recent first. */
    @Query("""
            SELECT b FROM BoardingRecord b
            WHERE b.student.id = :studentId
            ORDER BY b.boardedAt DESC
            """)
    List<BoardingRecord> findByStudentIdOrderByBoardedAtDesc(@Param("studentId") Long studentId);
}

package com.shuttle.domain.repository;

import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.enums.PassStatus;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MonthlyPassRepository extends JpaRepository<MonthlyPass, Long> {

    List<MonthlyPass> findByStudentId(Long studentId);

    List<MonthlyPass> findByStudentIdAndStatus(Long studentId, PassStatus status);

    /**
     * Returns the single ACTIVE pass for a student that covers the given date.
     * Used by the boarding flow to check pass eligibility.
     */
    @Query("""
            SELECT p FROM MonthlyPass p
            WHERE p.student.id = :studentId
              AND p.status     = 'ACTIVE'
              AND p.validFrom  <= :date
              AND p.validTo    >= :date
            ORDER BY p.validFrom DESC
            """)
    Optional<MonthlyPass> findActivePassForDate(
            @Param("studentId") Long studentId,
            @Param("date")      LocalDate date);

    /**
     * Checks whether the student has any ACTIVE or PENDING pass whose validity
     * window overlaps with [from, to]. Used to prevent double-purchasing.
     */
    @Query("""
            SELECT COUNT(p) > 0 FROM MonthlyPass p
            WHERE p.student.id = :studentId
              AND p.status IN ('ACTIVE', 'PENDING')
              AND p.validFrom  <= :to
              AND p.validTo    >= :from
            """)
    boolean existsOverlappingPass(
            @Param("studentId") Long studentId,
            @Param("from")      LocalDate from,
            @Param("to")        LocalDate to);

    /**
     * Bulk-expires passes whose validTo < today and are still ACTIVE.
     * Called by the nightly scheduled job.
     */
    @Modifying
    @Query("""
            UPDATE MonthlyPass p
            SET p.status = 'EXPIRED'
            WHERE p.status = 'ACTIVE'
              AND p.validTo < :today
            """)
    int expirePassesBefore(@Param("today") LocalDate today);
}

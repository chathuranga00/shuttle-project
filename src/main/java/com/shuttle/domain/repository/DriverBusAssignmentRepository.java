package com.shuttle.domain.repository;

import com.shuttle.domain.entity.DriverBusAssignment;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DriverBusAssignmentRepository extends JpaRepository<DriverBusAssignment, Long> {

    /** Returns the currently active assignment for a driver (unassigned_at IS NULL). */
    @Query("SELECT a FROM DriverBusAssignment a WHERE a.driver.id = :driverId AND a.unassignedAt IS NULL ORDER BY a.assignedAt DESC")
    List<DriverBusAssignment> findAllCurrentByDriverId(@Param("driverId") Long driverId);

    default Optional<DriverBusAssignment> findCurrentByDriverId(Long driverId) {
        List<DriverBusAssignment> list = findAllCurrentByDriverId(driverId);
        return list.isEmpty() ? Optional.empty() : Optional.of(list.get(0));
    }

    /** Closes all open assignments for a driver (sets unassigned_at to now). */
    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE DriverBusAssignment a SET a.unassignedAt = :now WHERE a.driver.id = :driverId AND a.unassignedAt IS NULL")
    int closeAssignmentsForDriver(@Param("driverId") Long driverId, @Param("now") java.time.Instant now);
}

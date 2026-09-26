package com.shuttle.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Records the assignment of a driver to a bus (and optionally a route).
 * A null {@code unassignedAt} means the assignment is current.
 */
@Getter
@Setter
@Entity
@Table(
        name = "driver_bus_assignments",
        indexes = {
                @Index(name = "idx_dba_driver", columnList = "driver_id"),
                @Index(name = "idx_dba_bus",    columnList = "bus_id")
        }
)
public class DriverBusAssignment extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "driver_id", nullable = false)
    private Driver driver;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "bus_id", nullable = false)
    private Bus bus;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "route_id")
    private Route route;

    @Column(name = "assigned_at", nullable = false)
    private Instant assignedAt;

    /** Null means the assignment is currently active. */
    @Column(name = "unassigned_at")
    private Instant unassignedAt;
}

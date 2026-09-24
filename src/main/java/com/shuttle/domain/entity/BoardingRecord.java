package com.shuttle.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(
        name = "boarding_records",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_boarding_records_trip_student",
                        columnNames = {"trip_id", "student_id"}),
                @UniqueConstraint(name = "uk_boarding_idempotency",
                        columnNames = {"idempotency_key"})
        },
        indexes = {
                @Index(name = "idx_boarding_records_student_id", columnList = "student_id"),
                @Index(name = "idx_boarding_records_boarded_at",  columnList = "boarded_at"),
                @Index(name = "idx_boarding_idempotency",         columnList = "idempotency_key")
        }
)
public class BoardingRecord extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id", nullable = false)
    private Student student;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "bus_stop_id", nullable = false)
    private BusStop busStop;

    @Column(name = "boarded_at", nullable = false)
    private Instant boardedAt;

    @Column(name = "fare_amount", precision = 10, scale = 2)
    private BigDecimal fareAmount;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pass_id")
    private MonthlyPass monthlyPass;

    /**
     * Client-supplied idempotency key. A second request with the same key
     * returns the existing record without creating a duplicate.
     */
    @Column(name = "idempotency_key", length = 64, unique = true)
    private String idempotencyKey;

    /**
     * Payment lifecycle status. Starts as UNPAID; a future payment step will
     * move it to PAID or FAILED.
     */
    @Column(name = "payment_status", nullable = false, length = 32)
    private String paymentStatus = "UNPAID";
}

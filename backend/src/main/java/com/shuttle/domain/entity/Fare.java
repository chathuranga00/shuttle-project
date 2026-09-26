package com.shuttle.domain.entity;

import com.shuttle.domain.enums.FareClass;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/**
 * A fare represents the boarding cost at a specific stop on a route,
 * valid for a date range. Only one active fare per (route, stop, fareClass)
 * can exist at any point in time — enforced at the service layer.
 *
 * <p>If {@code effectiveUntil} is {@code null} the fare is open-ended
 * (active until superseded by a new fare or manually closed).
 */
@Getter
@Setter
@Entity
@Table(
        name = "fares",
        indexes = {
                @Index(name = "idx_fares_route_id",  columnList = "route_id"),
                @Index(name = "idx_fares_stop_id",   columnList = "stop_id"),
                @Index(name = "idx_fares_effective",
                       columnList = "route_id, stop_id, fare_class, effective_from")
        }
)
public class Fare extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "route_id", nullable = false)
    private Route route;

    /** The bus stop at which this fare applies (boarding stop). */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "stop_id", nullable = false)
    private BusStop stop;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(name = "fare_class", nullable = false, length = 32)
    private FareClass fareClass = FareClass.STANDARD;

    /** Inclusive start date from which this fare is valid. */
    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    /**
     * Inclusive end date until which this fare is valid.
     * {@code null} means the fare is open-ended (valid indefinitely).
     */
    @Column(name = "effective_until")
    private LocalDate effectiveUntil;
}

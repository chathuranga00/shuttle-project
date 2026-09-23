package com.shuttle.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(
        name = "route_stops",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_route_stops_route_stop", columnNames = {"route_id", "bus_stop_id"}),
                @UniqueConstraint(name = "uk_route_stops_route_order", columnNames = {"route_id", "stop_order"})
        }
)
public class RouteStop extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "route_id", nullable = false)
    private Route route;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "bus_stop_id", nullable = false)
    private BusStop busStop;

    @Column(name = "stop_order", nullable = false)
    private Integer stopOrder;

    @Column(name = "estimated_offset_minutes")
    private Integer estimatedOffsetMinutes;
}

package com.shuttle.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name = "bus_locations")
public class BusLocation extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "bus_id", nullable = false, unique = true)
    private Bus bus;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @Column(precision = 10, scale = 7, nullable = false)
    private BigDecimal latitude;

    @Column(precision = 10, scale = 7, nullable = false)
    private BigDecimal longitude;

    @Column(name = "heading")
    private Double heading;

    @Column(name = "speed_kmh")
    private Double speedKmh;

    public BusLocation(Bus bus, Trip trip, BigDecimal latitude, BigDecimal longitude, Double heading, Double speedKmh) {
        this.bus = bus;
        this.trip = trip;
        this.latitude = latitude;
        this.longitude = longitude;
        this.heading = heading;
        this.speedKmh = speedKmh;
    }
}

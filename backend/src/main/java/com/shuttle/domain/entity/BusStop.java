package com.shuttle.domain.entity;

import com.shuttle.domain.enums.StopStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.math.BigDecimal;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(
        name = "bus_stops",
        uniqueConstraints = @UniqueConstraint(name = "uk_bus_stops_qr_code", columnNames = "qr_code"),
        indexes = @Index(name = "idx_bus_stops_status", columnList = "status")
)
public class BusStop extends BaseEntity {

    @Column(nullable = false, length = 150)
    private String name;

    @Column(name = "qr_code", nullable = false, unique = true, length = 100)
    private String qrCode;

    @Column(precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(length = 255)
    private String address;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private StopStatus status = StopStatus.ACTIVE;
}

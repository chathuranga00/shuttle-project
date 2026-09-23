package com.shuttle.domain.entity;

import com.shuttle.domain.enums.BusStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "buses")
public class Bus extends BaseEntity {

    @Column(name = "bus_number", nullable = false, unique = true, length = 50)
    private String busNumber;

    @Column(name = "plate_number", nullable = false, unique = true, length = 20)
    private String plateNumber;

    @Column(nullable = false)
    private Integer capacity;

    @Column(length = 100)
    private String model;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private BusStatus status = BusStatus.ACTIVE;
}

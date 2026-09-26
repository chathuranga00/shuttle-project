package com.shuttle.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(
        name = "emergency_reports",
        indexes = {
                @Index(name = "idx_er_driver", columnList = "driver_id"),
                @Index(name = "idx_er_created", columnList = "created_at")
        }
)
public class EmergencyReport extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "driver_id", nullable = false)
    private Driver driver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @Column(nullable = false, length = 50)
    private String type;

    @Column(nullable = false, length = 1000)
    private String description;

    @Column(length = 255)
    private String location;

    @Column(nullable = false, length = 32)
    private String status = "REPORTED";
}

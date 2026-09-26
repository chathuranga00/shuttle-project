package com.shuttle.domain.entity;

import com.shuttle.domain.enums.RouteStatus;
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
@Table(name = "routes")
public class Route extends BaseEntity {

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(length = 500)
    private String description;

    @Column(name = "estimated_duration_minutes")
    private Integer estimatedDurationMinutes;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private RouteStatus status = RouteStatus.ACTIVE;
}

package com.shuttle.location.dto;

import java.math.BigDecimal;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BusLocationResponse {

    private Long id;
    private Long busId;
    private String busNumber;
    private Long tripId;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private Double heading;
    private Double speedKmh;
    private Instant updatedAt;
    private boolean cleared;
}

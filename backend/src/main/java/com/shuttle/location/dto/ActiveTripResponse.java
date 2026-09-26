package com.shuttle.location.dto;

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
public class ActiveTripResponse {

    private Long tripId;
    private Long routeId;
    private String routeName;
    private String routeCode;
    private Long busId;
    private String busNumber;
    private String status;
    private Instant actualStart;
}

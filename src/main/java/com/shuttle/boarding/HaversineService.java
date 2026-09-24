package com.shuttle.boarding;

import org.springframework.stereotype.Service;

/**
 * Pure Haversine distance calculation — no I/O, no state, fully unit-testable.
 *
 * <p>The Haversine formula gives the great-circle distance between two points
 * on a sphere given their latitudes and longitudes. The result is in metres.
 *
 * <p>Earth radius: 6371000 m (volumetric mean radius).
 */
@Service
public class HaversineService {

    private static final double EARTH_RADIUS_M = 6_371_000.0;

    /**
     * Calculates the great-circle distance between two WGS-84 coordinates.
     *
     * @param lat1 latitude of point 1 (degrees)
     * @param lon1 longitude of point 1 (degrees)
     * @param lat2 latitude of point 2 (degrees)
     * @param lon2 longitude of point 2 (degrees)
     * @return distance in metres
     */
    public double distanceMetres(double lat1, double lon1,
                                  double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double sinHalfLat = Math.sin(dLat / 2);
        double sinHalfLon = Math.sin(dLon / 2);

        double a = sinHalfLat * sinHalfLat
                + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * sinHalfLon * sinHalfLon;

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_M * c;
    }

    /**
     * Returns {@code true} when the student's position is within
     * {@code radiusMetres} of the stop.
     *
     * @param studentLat  student latitude
     * @param studentLon  student longitude
     * @param stopLat     stop latitude
     * @param stopLon     stop longitude
     * @param radiusMetres configured GPS radius (from system settings)
     */
    public boolean isWithinRadius(double studentLat, double studentLon,
                                   double stopLat,    double stopLon,
                                   double radiusMetres) {
        return distanceMetres(studentLat, studentLon, stopLat, stopLon) <= radiusMetres;
    }
}

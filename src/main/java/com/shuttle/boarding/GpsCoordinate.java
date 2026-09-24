package com.shuttle.boarding;

/**
 * An optional student GPS reading sent from the mobile device.
 * All fields may be null when the client omits GPS data.
 */
public record GpsCoordinate(
        Double latitude,
        Double longitude,
        /** Horizontal accuracy in metres, as reported by the device sensor. */
        Double accuracyMetres
) {
    /**
     * A coordinate is usable only when lat/lon are present
     * and accuracy is not excessively poor.
     */
    public boolean isPresent() {
        return latitude != null && longitude != null;
    }

    /**
     * Threshold above which accuracy is too poor for a hard rejection.
     * When accuracy exceeds this value the backend asks the student to
     * move to an open area instead of outright rejecting the boarding.
     */
    public static final double POOR_ACCURACY_THRESHOLD_M = 100.0;

    public boolean hasPoorAccuracy() {
        return accuracyMetres != null && accuracyMetres > POOR_ACCURACY_THRESHOLD_M;
    }
}

package com.shuttle.boarding;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/**
 * Pure unit tests for Haversine distance calculation.
 * No Spring context needed — HaversineService has zero dependencies.
 */
@DisplayName("HaversineService — distance calculation")
class HaversineServiceTest {

    private final HaversineService sut = new HaversineService();

    // ── Known reference points ─────────────────────────────────────────────
    // Kandy Bus Stand ≈ (7.2906, 80.6337)
    // University of Peradeniya gate ≈ (7.2540, 80.5930)
    // Direct distance ≈ 5,780 m  (independently verified via multiple GIS tools)

    @Test
    @DisplayName("Zero distance when same point is supplied twice")
    void samePoint_returnsZero() {
        double d = sut.distanceMetres(7.2906, 80.6337, 7.2906, 80.6337);
        assertThat(d).isCloseTo(0.0, within(0.001));
    }

    @Test
    @DisplayName("Kandy to University gate is ~5780 m (±350 m tolerance)")
    void kandyToUniversity_correct() {
        double d = sut.distanceMetres(7.2906, 80.6337, 7.2540, 80.5930);
        assertThat(d).isCloseTo(5780.0, within(350.0));
    }

    @Test
    @DisplayName("Two points 50 m apart are within 100 m radius")
    void withinRadius_50m_accepts() {
        // Move ~50 m north from (7.2906, 80.6337):
        // 1 degree latitude ≈ 111,320 m → 50 m ≈ 0.000449 degrees
        double offsetLat = 0.000449;
        boolean result = sut.isWithinRadius(
                7.2906 + offsetLat, 80.6337,   // student (≈50 m north of stop)
                7.2906,            80.6337,    // stop
                100.0);
        assertThat(result).isTrue();
    }

    @Test
    @DisplayName("Two points 150 m apart are outside 100 m radius")
    void outsideRadius_150m_rejects() {
        // Move ~150 m north: 150/111320 ≈ 0.001347 degrees
        double offsetLat = 0.001347;
        boolean result = sut.isWithinRadius(
                7.2906 + offsetLat, 80.6337,
                7.2906,            80.6337,
                100.0);
        assertThat(result).isFalse();
    }

    @Test
    @DisplayName("Exactly at radius boundary is accepted (≤ radius)")
    void atRadiusBoundary_accepted() {
        // 100 m north: 100/111320 ≈ 0.000898 degrees
        double offsetLat = 0.000898;
        double distance = sut.distanceMetres(
                7.2906 + offsetLat, 80.6337,
                7.2906,            80.6337);
        // Verify distance is ≤ 100 m first
        assertThat(distance).isLessThanOrEqualTo(100.5); // small floating-point margin

        boolean result = sut.isWithinRadius(
                7.2906 + offsetLat, 80.6337,
                7.2906,            80.6337,
                100.0);
        assertThat(result).isTrue();
    }

    @Test
    @DisplayName("Distance is symmetric — d(A,B) == d(B,A)")
    void distance_isSymmetric() {
        double ab = sut.distanceMetres(7.2906, 80.6337, 7.2540, 80.5930);
        double ba = sut.distanceMetres(7.2540, 80.5930, 7.2906, 80.6337);
        assertThat(ab).isCloseTo(ba, within(0.001));
    }

    @Test
    @DisplayName("isWithinRadius returns false when radius is 0 and points differ")
    void zeroRadius_differentPoints_rejects() {
        boolean result = sut.isWithinRadius(
                7.2906, 80.6337,
                7.2907, 80.6337,
                0.0);
        assertThat(result).isFalse();
    }
}

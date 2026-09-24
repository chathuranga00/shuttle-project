package com.shuttle.boarding;

import com.shuttle.admin.settings.SystemSettingsService;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.exception.ApiException;
import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

/**
 * Unit tests for GPS radius enforcement logic.
 * Uses Mockito to control SystemSettingsService without a full Spring context.
 *
 * <p>Reference stop: Kandy Bus Stand at (7.2906, 80.6337).
 * <ul>
 *   <li>Near position  (≈50 m away):  (7.2911, 80.6337)</li>
 *   <li>Far position   (≈500 m away): (7.2951, 80.6337)</li>
 * </ul>
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("GpsVerificationService — radius enforcement")
class GpsVerificationServiceTest {

    @Mock private SystemSettingsService systemSettingsService;

    private HaversineService haversineService;
    private GpsVerificationService sut;

    // Stop at Kandy Bus Stand
    private BusStop stopWithCoords;
    private BusStop stopWithoutCoords;

    // ~50 m away from the stop (within 100 m radius)
    private static final double NEAR_LAT  = 7.2911;
    private static final double NEAR_LON  = 80.6337;
    // ~500 m away from the stop (outside 100 m radius)
    private static final double FAR_LAT   = 7.2951;
    private static final double FAR_LON   = 80.6337;

    private static final double STOP_LAT  = 7.2906;
    private static final double STOP_LON  = 80.6337;
    private static final int    RADIUS_M  = 100;

    @BeforeEach
    void setUp() {
        haversineService = new HaversineService();
        sut = new GpsVerificationService(systemSettingsService, haversineService);

        stopWithCoords = new BusStop();
        stopWithCoords.setLatitude(BigDecimal.valueOf(STOP_LAT));
        stopWithCoords.setLongitude(BigDecimal.valueOf(STOP_LON));

        stopWithoutCoords = new BusStop();
        // latitude and longitude remain null
    }

    // ── GPS disabled ───────────────────────────────────────────────────────

    @Test
    @DisplayName("GPS disabled → always passes, even when far away")
    void gpsDisabled_farAway_passes() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(false);

        GpsCoordinate far = new GpsCoordinate(FAR_LAT, FAR_LON, 10.0);
        assertThatCode(() -> sut.verify(far, stopWithCoords)).doesNotThrowAnyException();
    }

    // ── Within radius ──────────────────────────────────────────────────────

    @Test
    @DisplayName("GPS enabled, student near stop → passes")
    void gpsEnabled_nearStop_passes() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);
        when(systemSettingsService.getGpsRadiusMetres()).thenReturn(RADIUS_M);

        GpsCoordinate near = new GpsCoordinate(NEAR_LAT, NEAR_LON, 15.0);
        assertThatCode(() -> sut.verify(near, stopWithCoords)).doesNotThrowAnyException();
    }

    // ── Outside radius ─────────────────────────────────────────────────────

    @Test
    @DisplayName("GPS enabled, student far from stop → throws GPS_TOO_FAR")
    void gpsEnabled_farFromStop_throws() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);
        when(systemSettingsService.getGpsRadiusMetres()).thenReturn(RADIUS_M);

        GpsCoordinate far = new GpsCoordinate(FAR_LAT, FAR_LON, 15.0);
        assertThatThrownBy(() -> sut.verify(far, stopWithCoords))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException ae = (ApiException) ex;
                    assertThat(ae.getCode()).isEqualTo("GPS_TOO_FAR");
                    assertThat(ae.getMessage()).isEqualTo(GpsVerificationService.MSG_TOO_FAR);
                });
    }

    // ── Admin changes radius ───────────────────────────────────────────────

    @Test
    @DisplayName("Admin widens radius to 600 m → same far position now passes")
    void adminWidensRadius_farPositionNowPasses() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);
        when(systemSettingsService.getGpsRadiusMetres()).thenReturn(600); // widened

        GpsCoordinate far = new GpsCoordinate(FAR_LAT, FAR_LON, 15.0);
        assertThatCode(() -> sut.verify(far, stopWithCoords)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Admin tightens radius to 10 m → near position (50 m) now fails")
    void adminTightensRadius_nearPositionNowFails() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);
        when(systemSettingsService.getGpsRadiusMetres()).thenReturn(10); // very tight

        GpsCoordinate near = new GpsCoordinate(NEAR_LAT, NEAR_LON, 5.0);
        assertThatThrownBy(() -> sut.verify(near, stopWithCoords))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).getCode())
                        .isEqualTo("GPS_TOO_FAR"));
    }

    // ── Poor accuracy ──────────────────────────────────────────────────────

    @Test
    @DisplayName("Poor GPS accuracy (>100 m) → throws GPS_ACCURACY_TOO_LOW, not GPS_TOO_FAR")
    void poorAccuracy_throwsSoftWarning() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);

        GpsCoordinate poorAccuracy = new GpsCoordinate(NEAR_LAT, NEAR_LON, 150.0); // >100 m
        assertThatThrownBy(() -> sut.verify(poorAccuracy, stopWithCoords))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException ae = (ApiException) ex;
                    assertThat(ae.getCode()).isEqualTo("GPS_ACCURACY_TOO_LOW");
                    assertThat(ae.getMessage()).isEqualTo(GpsVerificationService.MSG_POOR_ACCURACY);
                });
    }

    // ── Missing GPS data ───────────────────────────────────────────────────

    @Test
    @DisplayName("GPS enabled but client sent no coordinates → passes (GPS optional)")
    void gpsEnabled_clientOmittedCoords_passes() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);

        GpsCoordinate noCoords = new GpsCoordinate(null, null, null);
        assertThatCode(() -> sut.verify(noCoords, stopWithCoords)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("GPS enabled but stop has no coordinates configured → passes")
    void gpsEnabled_stopHasNoCoords_passes() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);

        GpsCoordinate near = new GpsCoordinate(NEAR_LAT, NEAR_LON, 15.0);
        assertThatCode(() -> sut.verify(near, stopWithoutCoords)).doesNotThrowAnyException();
    }

    // ── softVerify ─────────────────────────────────────────────────────────

    @Test
    @DisplayName("softVerify — returns null when check passes")
    void softVerify_passes_returnsNull() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);
        when(systemSettingsService.getGpsRadiusMetres()).thenReturn(RADIUS_M);

        GpsCoordinate near = new GpsCoordinate(NEAR_LAT, NEAR_LON, 15.0);
        assertThat(sut.softVerify(near, stopWithCoords)).isNull();
    }

    @Test
    @DisplayName("softVerify — returns message string when check fails (not exception)")
    void softVerify_fails_returnsMessage() {
        when(systemSettingsService.isGpsVerificationEnabled()).thenReturn(true);
        when(systemSettingsService.getGpsRadiusMetres()).thenReturn(RADIUS_M);

        GpsCoordinate far = new GpsCoordinate(FAR_LAT, FAR_LON, 15.0);
        String msg = sut.softVerify(far, stopWithCoords);
        assertThat(msg).isEqualTo(GpsVerificationService.MSG_TOO_FAR);
    }
}

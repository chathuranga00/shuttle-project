package com.shuttle.boarding;

import com.shuttle.admin.settings.SystemSettingsService;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Applies GPS proximity verification during boarding.
 *
 * <p>Decision table:
 * <pre>
 * GPS enabled?  | Coord present? | Poor accuracy? | Action
 * --------------|----------------|----------------|-----------------------------
 * false         | any            | any            | Skip (pass)
 * true          | false (null)   | —              | Skip — client didn't send GPS
 * true          | true           | true           | Warn: "move to open area"
 * true          | true           | false          | Enforce radius check
 * </pre>
 *
 * <p>If the stop has no configured coordinates, GPS check is skipped regardless.
 */
@Service
@RequiredArgsConstructor
public class GpsVerificationService {

    static final String MSG_TOO_FAR =
            "You are not currently near this bus stop.";
    static final String MSG_POOR_ACCURACY =
            "Your GPS accuracy is too low. Please move to an open area and try again.";

    private final SystemSettingsService systemSettingsService;
    private final HaversineService      haversineService;

    /**
     * Runs GPS verification and throws {@link ApiException} if the student is
     * too far from the stop.
     *
     * <p>Never throws when GPS is disabled in settings or when the stop has
     * no coordinates configured.
     *
     * @param coord  student GPS reading (may be null / have null fields)
     * @param stop   the bus stop being boarded
     */
    public void verify(GpsCoordinate coord, BusStop stop) {
        // 1. Feature toggle
        if (!systemSettingsService.isGpsVerificationEnabled()) {
            return;
        }

        // 2. Stop must have coordinates configured
        if (stop.getLatitude() == null || stop.getLongitude() == null) {
            return;   // stop has no GPS data — cannot enforce proximity
        }

        // 3. Client must have sent coordinates (optional field)
        if (coord == null || !coord.isPresent()) {
            return;   // client omitted GPS — allow without checking
        }

        // 4. Poor accuracy → soft warning instead of hard rejection
        if (coord.hasPoorAccuracy()) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "GPS_ACCURACY_TOO_LOW", MSG_POOR_ACCURACY);
        }

        // 5. Enforce radius
        double radiusM = systemSettingsService.getGpsRadiusMetres();
        boolean near = haversineService.isWithinRadius(
                coord.latitude(),   coord.longitude(),
                stop.getLatitude().doubleValue(),
                stop.getLongitude().doubleValue(),
                radiusM);

        if (!near) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "GPS_TOO_FAR", MSG_TOO_FAR);
        }
    }

    /**
     * Non-throwing version used by the validate endpoint — returns a
     * human-readable rejection message instead of throwing, so the client
     * can show the message in the scanner without an HTTP error status.
     *
     * @return null when the check passes; an error message string when it fails
     */
    public String softVerify(GpsCoordinate coord, BusStop stop) {
        try {
            verify(coord, stop);
            return null;
        } catch (ApiException ex) {
            return ex.getMessage();
        }
    }
}

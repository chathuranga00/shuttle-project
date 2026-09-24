package com.shuttle.boarding;

import com.shuttle.admin.fare.FareService;
import com.shuttle.admin.stop.BusStopService;
import com.shuttle.boarding.dto.BoardingConfirmResponse;
import com.shuttle.boarding.dto.BoardingHistoryItem;
import com.shuttle.boarding.dto.ConfirmBoardingRequest;
import com.shuttle.boarding.dto.ValidateBoardingRequest;
import com.shuttle.boarding.dto.ValidateBoardingResponse;
import com.shuttle.domain.entity.BoardingRecord;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Fare;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.entity.VirtualBusCard;
import com.shuttle.domain.enums.CardStatus;
import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.domain.repository.VirtualBusCardRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.security.UserPrincipal;
import jakarta.persistence.EntityNotFoundException;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Core boarding flow — no payments, no GPS (deferred to later steps).
 *
 * <p>Identity contract: student identity is derived exclusively from the JWT
 * principal. No student ID or fare is accepted from the client.
 */
@Service
@RequiredArgsConstructor
public class BoardingService {

    // ── Error messages aligned with spec §28 ──────────────────────────────────
    static final String MSG_ALREADY_BOARDED     = "You have already boarded this trip.";
    static final String MSG_TRIP_NOT_ACTIVE      = "This trip is not currently active.";
    static final String MSG_STOP_NOT_IN_ROUTE    = "This stop is not part of the trip's route.";
    static final String MSG_STUDENT_SUSPENDED    = "Your account has been suspended. Please contact support.";
    static final String MSG_CARD_NOT_ACTIVE      = "Your virtual bus card is not active.";
    static final String MSG_QR_INVALID           = "Invalid QR code. Please scan the stop QR code again.";
    static final String MSG_TRIP_AMBIGUOUS       = "Multiple active trips serve this stop. Please specify a trip.";
    static final String MSG_TRIP_NOT_FOUND       = "No active trip found for this stop.";

    private final BusStopService             busStopService;
    private final FareService                fareService;
    private final StudentRepository          studentRepository;
    private final VirtualBusCardRepository   virtualBusCardRepository;
    private final TripRepository             tripRepository;
    private final BoardingRecordRepository   boardingRecordRepository;
    private final BoardingWriter             boardingWriter;
    private final GpsVerificationService     gpsVerificationService;
    private final MonthlyPassRepository      monthlyPassRepository;

    // ── Validate (read-only, nothing is saved) ────────────────────────────────

    /**
     * Verifies a stop QR and finds the active trip. Returns a preview for
     * the student to confirm before the actual boarding is committed.
     * Nothing is persisted — this endpoint is safe to call multiple times.
     */
    @Transactional(readOnly = true)
    public ValidateBoardingResponse validate(ValidateBoardingRequest req) {
        // 1. Verify stop QR signature
        BusStop stop;
        try {
            stop = busStopService.verifyQrPayload(req.stopQrPayload());
        } catch (ApiException ex) {
            return invalid(MSG_QR_INVALID);
        }

        // 2. Find the active trip(s) for this stop
        List<Trip> activeTrips = tripRepository.findActiveTripsForStop(stop.getId());
        if (activeTrips.isEmpty()) {
            return invalid(MSG_TRIP_NOT_FOUND);
        }

        Trip trip;
        if (req.tripId() != null) {
            trip = activeTrips.stream()
                    .filter(t -> t.getId().equals(req.tripId()))
                    .findFirst()
                    .orElse(null);
            if (trip == null) {
                return invalid(MSG_TRIP_NOT_ACTIVE);
            }
        } else if (activeTrips.size() == 1) {
            trip = activeTrips.get(0);
        } else {
            // Multiple trips — client must specify one
            return new ValidateBoardingResponse(false, MSG_TRIP_AMBIGUOUS,
                    stop.getName(), null, null, null);
        }

        // 3. Look up fare (not an error if absent — returned as null)
        BigDecimal fare = fareService
                .findCurrentFareEntity(trip.getRoute().getId(), stop.getId())
                .map(Fare::getAmount)
                .orElse(null);

        // 4. Optional GPS proximity check (soft — returns message, not exception)
        GpsCoordinate coord = buildCoord(req.latitude(), req.longitude(), req.accuracyMeters());
        String gpsMessage = gpsVerificationService.softVerify(coord, stop);
        if (gpsMessage != null) {
            return new ValidateBoardingResponse(false, gpsMessage,
                    stop.getName(), trip.getRoute().getName(), trip.getId(), fare);
        }

        return new ValidateBoardingResponse(
                true, "Boarding validated successfully.",
                stop.getName(), trip.getRoute().getName(),
                trip.getId(), fare);
    }

    // ── Confirm (transactional write) ─────────────────────────────────────────

    /**
     * Performs the full boarding validation and, if all checks pass, saves a
     * {@link BoardingRecord} with {@code paymentStatus = UNPAID}.
     * Idempotent on {@code idempotencyKey}. Student identity from JWT only.
     */
    @Transactional
    public BoardingConfirmResponse confirm(ConfirmBoardingRequest req, Authentication auth) {
        // 0. Idempotency check — return existing record immediately if key was seen before
        Optional<BoardingRecord> existing =
                boardingRecordRepository.findByIdempotencyKey(req.idempotencyKey());
        if (existing.isPresent()) {
            return toConfirmResponse(existing.get(), true);
        }

        // 1. Resolve student from JWT — never from the request body
        Student student = resolveStudent(auth);

        // 2. Student account must be ACTIVE
        if (student.getUser().getStatus() != UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.FORBIDDEN, "STUDENT_SUSPENDED", MSG_STUDENT_SUSPENDED);
        }

        // 3. Virtual bus card must be ACTIVE
        VirtualBusCard card = virtualBusCardRepository.findByStudentId(student.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN,
                        "CARD_NOT_FOUND", MSG_CARD_NOT_ACTIVE));
        if (card.getStatus() != CardStatus.ACTIVE) {
            throw new ApiException(HttpStatus.FORBIDDEN, "CARD_NOT_ACTIVE", MSG_CARD_NOT_ACTIVE);
        }

        // 4. Verify stop QR signature
        BusStop stop;
        try {
            stop = busStopService.verifyQrPayload(req.stopQrPayload());
        } catch (ApiException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "QR_INVALID", MSG_QR_INVALID);
        }

        // 4b. GPS proximity check (hard — throws ApiException if outside radius)
        GpsCoordinate coord = buildCoord(req.latitude(), req.longitude(), req.accuracyMeters());
        gpsVerificationService.verify(coord, stop);

        // 5. Trip must exist and be IN_PROGRESS
        Trip trip = tripRepository.findById(req.tripId())
                .orElseThrow(() -> new EntityNotFoundException("Trip " + req.tripId() + " not found."));
        if (trip.getStatus() != TripStatus.IN_PROGRESS) {
            throw new ApiException(HttpStatus.CONFLICT, "TRIP_NOT_ACTIVE", MSG_TRIP_NOT_ACTIVE);
        }

        // 6. Stop must belong to the trip's route
        boolean stopInRoute = tripRepository.findActiveTripsForStop(stop.getId())
                .stream()
                .anyMatch(t -> t.getId().equals(trip.getId()));
        if (!stopInRoute) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "STOP_NOT_IN_ROUTE", MSG_STOP_NOT_IN_ROUTE);
        }

        // 7. Student must not have already boarded this trip
        if (boardingRecordRepository.existsByTripIdAndStudentId(trip.getId(), student.getId())) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_BOARDED", MSG_ALREADY_BOARDED);
        }

        // 8. Calculate fare: active monthly pass → fare=0, paymentStatus=PASS;
        //    otherwise look up from fares table (never from client).
        java.time.LocalDate today = java.time.LocalDate.now();
        MonthlyPass activePass = monthlyPassRepository
                .findActivePassForDate(student.getId(), today)
                .orElse(null);

        BigDecimal fareAmount;
        if (activePass != null) {
            fareAmount = BigDecimal.ZERO;
        } else {
            fareAmount = fareService
                    .findCurrentFareEntity(trip.getRoute().getId(), stop.getId())
                    .map(Fare::getAmount)
                    .orElse(null);
        }

        // 9. Persist boarding record via the writer (owns its own @Transactional)
        return boardingWriter.save(student, trip, stop, fareAmount,
                req.idempotencyKey(), coord, activePass);
    }

    // ── History (read-only) ───────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<BoardingHistoryItem> getHistory(Authentication auth) {
        Student student = resolveStudent(auth);
        return boardingRecordRepository
                .findByStudentIdOrderByBoardedAtDesc(student.getId())
                .stream()
                .map(this::toHistoryItem)
                .collect(Collectors.toList());
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private Student resolveStudent(Authentication auth) {
        UserPrincipal principal = (UserPrincipal) auth.getPrincipal();
        return studentRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "STUDENT_NOT_FOUND", "Student profile not found."));
    }

    private BoardingConfirmResponse toConfirmResponse(BoardingRecord r, boolean alreadyBoarded) {
        return new BoardingConfirmResponse(
                r.getId(),
                r.getTrip().getId(),
                r.getTrip().getRoute().getName(),
                r.getBusStop().getName(),
                r.getFareAmount(),
                r.getPaymentStatus(),
                r.getBoardedAt(),
                alreadyBoarded);
    }

    private BoardingHistoryItem toHistoryItem(BoardingRecord r) {
        return new BoardingHistoryItem(
                r.getId(),
                r.getTrip().getId(),
                r.getTrip().getRoute().getName(),
                r.getBusStop().getName(),
                r.getFareAmount(),
                r.getPaymentStatus(),
                r.getBoardedAt());
    }

    private static ValidateBoardingResponse invalid(String message) {
        return new ValidateBoardingResponse(false, message, null, null, null, null);
    }

    private static GpsCoordinate buildCoord(Double lat, Double lon, Double accuracy) {
        return new GpsCoordinate(lat, lon, accuracy);
    }
}

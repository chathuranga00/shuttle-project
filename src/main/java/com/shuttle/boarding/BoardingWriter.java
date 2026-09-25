package com.shuttle.boarding;

import com.shuttle.boarding.dto.BoardingConfirmResponse;
import com.shuttle.domain.entity.BoardingRecord;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.entity.WalletTransaction;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.domain.repository.WalletTransactionRepository;
import com.shuttle.domain.enums.NotificationType;
import com.shuttle.exception.ApiException;
import com.shuttle.notification.NotificationService;
import com.shuttle.wallet.WalletService;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Owns the write side of the boarding flow.
 */
@Service
@RequiredArgsConstructor
public class BoardingWriter {

    private final BoardingRecordRepository  boardingRecordRepository;
    private final WalletService             walletService;
    private final com.shuttle.domain.repository.WalletRepository walletRepository;
    private final WalletTransactionRepository walletTxRepository;
    private final NotificationService       notificationService;

    @Transactional
    public BoardingConfirmResponse save(Student student, Trip trip,
            BusStop stop, BigDecimal fareAmount, String idempotencyKey,
            GpsCoordinate coord, MonthlyPass activePass) {

        // ── Concurrency guard: lock student's wallet to serialize all boarding operations ──
        walletRepository.findByStudentIdWithLock(student.getId());

        // Under serialized lock, re-verify student hasn't already boarded
        if (boardingRecordRepository.existsByTripIdAndStudentId(trip.getId(), student.getId())) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_BOARDED", BoardingService.MSG_ALREADY_BOARDED);
        }

        // ── Build the record (not yet persisted) ──────────────────────────────
        BoardingRecord record = new BoardingRecord();
        record.setTrip(trip);
        record.setStudent(student);
        record.setBusStop(stop);
        record.setBoardedAt(Instant.now());
        record.setFareAmount(fareAmount);
        record.setIdempotencyKey(idempotencyKey);

        if (coord != null && coord.isPresent()) {
            record.setBoardingLatitude(BigDecimal.valueOf(coord.latitude()));
            record.setBoardingLongitude(BigDecimal.valueOf(coord.longitude()));
        }

        // ── Determine payment status and perform wallet deduction ─────────────
        WalletTransaction walletTx = null;

        if (activePass != null) {
            record.setMonthlyPass(activePass);
            record.setPaymentStatus("PASS");

        } else if (fareAmount != null && fareAmount.compareTo(BigDecimal.ZERO) > 0) {
            // Step 1: deduct FIRST (before inserting the boarding record).
            // WalletService.deductFare acquires a PESSIMISTIC_WRITE lock on the wallet,
            // checks balance, deducts, and writes the WalletTransaction row.
            // If balance is insufficient this throws immediately — session stays clean.
            walletTx = walletService.deductFare(student.getId(), fareAmount, null);
            record.setPaymentStatus("PAID");

        } else {
            record.setPaymentStatus("UNPAID");
        }

        // ── Persist the boarding record ───────────────────────────────────────
        try {
            record = boardingRecordRepository.save(record);
            boardingRecordRepository.flush();
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            // Race condition — another concurrent request inserted (trip, student) first.
            // Rollback will undo the wallet deduction too (same transaction).
            BoardingRecord winner = boardingRecordRepository
                    .findByTripIdAndStudentId(trip.getId(), student.getId())
                    .orElseThrow(() -> new ApiException(HttpStatus.CONFLICT,
                            "ALREADY_BOARDED", BoardingService.MSG_ALREADY_BOARDED));
            return toResponse(winner, true);
        }

        // ── Back-fill wallet transaction referenceId now that we have the record ID ──
        if (walletTx != null) {
            walletTx.setReferenceId(record.getId());
            walletTxRepository.save(walletTx);
        }

        if (student.getUser() != null) {
            String routeName = trip.getRoute() != null ? trip.getRoute().getName() : "Shuttle";
            String stopName = stop != null ? stop.getName() : "Bus Stop";
            notificationService.createNotification(
                    student.getUser(),
                    "Boarding Confirmed",
                    "You boarded " + routeName + " at " + stopName + ".",
                    NotificationType.TRIP_UPDATE
            );
            if (walletTx != null && walletTx.getBalanceAfter() != null) {
                notificationService.checkAndNotifyLowBalance(student.getUser(), walletTx.getBalanceAfter());
            }
        }

        return toResponse(record, false);
    }

    private BoardingConfirmResponse toResponse(BoardingRecord r, boolean alreadyBoarded) {
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
}

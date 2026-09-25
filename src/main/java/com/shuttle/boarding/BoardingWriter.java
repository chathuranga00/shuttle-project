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
import com.shuttle.exception.ApiException;
import com.shuttle.wallet.WalletService;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Owns the write side of the boarding flow.
 *
 * <p>Ordering for the wallet-deduction path (critical for correctness):
 * <ol>
 *   <li>Acquire a PESSIMISTIC_WRITE lock on the wallet row and verify balance ≥ fare.
 *       This throws immediately if balance is insufficient — before any boarding record
 *       is written, so Hibernate session state remains clean.</li>
 *   <li>Deduct the balance and write a WalletTransaction row (referenceId = null initially).</li>
 *   <li>Save the BoardingRecord, now that the wallet check passed.</li>
 *   <li>Back-fill WalletTransaction.referenceId with the boarding record's ID.</li>
 * </ol>
 *
 * <p>Race-condition duplicate (trip+student): the DB unique constraint on
 * (trip_id, student_id) catches concurrent inserts; we return the winning record.
 */
@Service
@RequiredArgsConstructor
public class BoardingWriter {

    private final BoardingRecordRepository  boardingRecordRepository;
    private final WalletService             walletService;
    private final WalletTransactionRepository walletTxRepository;

    @Transactional
    public BoardingConfirmResponse save(Student student, Trip trip,
            BusStop stop, BigDecimal fareAmount, String idempotencyKey,
            GpsCoordinate coord, MonthlyPass activePass) {

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

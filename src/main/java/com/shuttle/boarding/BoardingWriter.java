package com.shuttle.boarding;

import com.shuttle.boarding.dto.BoardingConfirmResponse;
import com.shuttle.domain.entity.BoardingRecord;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.exception.ApiException;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Owns the write side of the boarding flow.
 * Extracted into its own bean so that Spring AOP can apply @Transactional
 * independently from the validation logic in {@link BoardingService}.
 * This prevents validation-time ApiExceptions from marking a write
 * transaction as rollback-only.
 */
@Service
@RequiredArgsConstructor
public class BoardingWriter {

    private final BoardingRecordRepository boardingRecordRepository;

    @Transactional
    public BoardingConfirmResponse save(Student student, Trip trip,
            BusStop stop, BigDecimal fareAmount, String idempotencyKey) {

        BoardingRecord record = new BoardingRecord();
        record.setTrip(trip);
        record.setStudent(student);
        record.setBusStop(stop);
        record.setBoardedAt(Instant.now());
        record.setFareAmount(fareAmount);
        record.setIdempotencyKey(idempotencyKey);
        record.setPaymentStatus("UNPAID");

        try {
            record = boardingRecordRepository.save(record);
            boardingRecordRepository.flush();
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            // Race condition: two concurrent requests for same (trip, student)
            BoardingRecord raceWinner = boardingRecordRepository
                    .findByTripIdAndStudentId(trip.getId(), student.getId())
                    .orElseThrow(() -> new ApiException(HttpStatus.CONFLICT,
                            "ALREADY_BOARDED", BoardingService.MSG_ALREADY_BOARDED));
            return toResponse(raceWinner, true);
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

package com.shuttle.boarding;

import com.shuttle.boarding.dto.BoardingConfirmResponse;
import com.shuttle.boarding.dto.BoardingHistoryItem;
import com.shuttle.boarding.dto.ConfirmBoardingRequest;
import com.shuttle.boarding.dto.ValidateBoardingRequest;
import com.shuttle.boarding.dto.ValidateBoardingResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/boarding")
@RequiredArgsConstructor
@Tag(name = "Boarding", description = "Student boarding flow — validate, confirm, history")
@SecurityRequirement(name = "bearerAuth")
public class BoardingController {

    private final BoardingService boardingService;

    /**
     * Validate a stop QR and find the active trip.
     * Read-only — nothing is saved. Safe to call repeatedly.
     */
    @PostMapping("/validate")
    @Operation(summary = "Validate a stop QR and preview boarding details")
    public ValidateBoardingResponse validate(@Valid @RequestBody ValidateBoardingRequest request) {
        return boardingService.validate(request);
    }

    /**
     * Confirm a boarding. Transactional — saves a boarding_record row.
     * Idempotent: retries with the same idempotencyKey return the existing record.
     */
    @PostMapping("/confirm")
    @Operation(summary = "Confirm boarding (idempotent)")
    public BoardingConfirmResponse confirm(
            @Valid @RequestBody ConfirmBoardingRequest request,
            Authentication authentication) {
        return boardingService.confirm(request, authentication);
    }

    /** Boarding history for the authenticated student, most recent first. */
    @GetMapping("/history")
    @Operation(summary = "Get boarding history for the authenticated student")
    public List<BoardingHistoryItem> getHistory(Authentication authentication) {
        return boardingService.getHistory(authentication);
    }
}

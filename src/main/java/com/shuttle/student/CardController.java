package com.shuttle.student;

import com.shuttle.student.dto.CardVerificationResponse;
import com.shuttle.student.dto.VerifyCardRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/cards")
@RequiredArgsConstructor
@Tag(name = "Cards", description = "Virtual bus card verification endpoints")
@SecurityRequirement(name = "bearerAuth")
public class CardController {

    private final CardTokenService cardTokenService;

    /**
     * Verifies a scanned QR boarding token.
     * Accessible by DRIVER or ADMIN roles only.
     *
     * @param request body containing the compact JWT from the student's QR code
     * @return student name, card ID, card status, and monthly pass status
     */
    @PostMapping("/verify")
    @Operation(summary = "Verify a student's QR boarding token (DRIVER or ADMIN only)")
    public CardVerificationResponse verifyCard(@Valid @RequestBody VerifyCardRequest request) {
        CardVerificationResult result = cardTokenService.verifyCardToken(request.token());
        return new CardVerificationResponse(
                result.studentName(),
                result.cardId(),
                result.cardStatus(),
                result.monthlyPassStatus()
        );
    }
}

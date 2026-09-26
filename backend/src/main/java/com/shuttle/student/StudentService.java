package com.shuttle.student;

import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.entity.VirtualBusCard;
import com.shuttle.domain.entity.Wallet;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.VirtualBusCardRepository;
import com.shuttle.domain.repository.WalletRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.security.UserPrincipal;
import com.shuttle.student.dto.StudentCardResponse;
import com.shuttle.student.dto.StudentProfileResponse;
import com.shuttle.student.dto.WalletSummary;
import jakarta.persistence.EntityNotFoundException;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class StudentService {

    private final StudentRepository studentRepository;
    private final WalletRepository walletRepository;
    private final VirtualBusCardRepository virtualBusCardRepository;
    private final MonthlyPassRepository monthlyPassRepository;
    private final CardTokenService cardTokenService;

    @Transactional(readOnly = true)
    public StudentProfileResponse getMyProfile(Authentication authentication) {
        Student student = resolveStudent(authentication);
        return new StudentProfileResponse(
                student.getUser().getId(),
                student.getUser().getEmail(),
                student.getUser().getFullName(),
                student.getUser().getPhone(),
                student.getStudentId(),
                student.getFaculty(),
                student.getEnrollmentYear()
        );
    }

    @Transactional(readOnly = true)
    public StudentCardResponse getMyCard(Authentication authentication) {
        Student student = resolveStudent(authentication);

        VirtualBusCard card = virtualBusCardRepository.findByStudentId(student.getId())
                .orElseThrow(() -> new EntityNotFoundException("Virtual bus card not found."));

        Wallet wallet = walletRepository.findByStudentId(student.getId())
                .orElseThrow(() -> new EntityNotFoundException("Wallet not found."));

        // Find latest active monthly pass if any
        List<MonthlyPass> activePasses =
                monthlyPassRepository.findByStudentIdAndStatus(student.getId(), PassStatus.ACTIVE);
        String passStatus = activePasses.isEmpty() ? "NONE" : "ACTIVE";

        WalletSummary walletSummary = new WalletSummary(
                wallet.getBalance(),
                wallet.getStatus().name()
        );

        // Generate a short-lived, signed QR token (60 s TTL, no PII)
        String qrToken = cardTokenService.generateQrToken(card.getCardId());

        return new StudentCardResponse(
                card.getCardId(),
                card.getStatus().name(),
                passStatus,
                walletSummary,
                qrToken
        );
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Student resolveStudent(Authentication authentication) {
        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        return studentRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "STUDENT_PROFILE_NOT_FOUND", "Student profile not found."));
    }
}

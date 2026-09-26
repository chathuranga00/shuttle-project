package com.shuttle.student;

import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.security.UserPrincipal;
import com.shuttle.student.dto.PaymentSummary;
import com.shuttle.student.dto.StudentCardResponse;
import com.shuttle.student.dto.StudentProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/students")
@RequiredArgsConstructor
@Tag(name = "Students", description = "Student self-service endpoints")
@SecurityRequirement(name = "bearerAuth")
public class StudentController {

    private final StudentService    studentService;
    private final StudentRepository studentRepository;
    private final PaymentRepository paymentRepository;

    @GetMapping("/me")
    @Operation(summary = "Get the authenticated student's profile")
    public StudentProfileResponse getMyProfile(Authentication authentication) {
        return studentService.getMyProfile(authentication);
    }

    @GetMapping("/me/card")
    @Operation(summary = "Get the authenticated student's virtual bus card summary")
    public StudentCardResponse getMyCard(Authentication authentication) {
        return studentService.getMyCard(authentication);
    }

    @GetMapping("/me/payments")
    @Operation(summary = "Get the authenticated student's payment history")
    public List<PaymentSummary> getMyPayments(Authentication authentication) {
        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        Long studentId = studentRepository.findByUserId(principal.getId())
                .map(s -> s.getId())
                .orElse(null);
        if (studentId == null) return List.of();

        return paymentRepository.findByStudentIdOrderByCreatedAtDesc(studentId)
                .stream()
                .map(p -> new PaymentSummary(p.getId(), p.getType().name(),
                        p.getAmount(), p.getStatus().name(), p.getCreatedAt()))
                .collect(Collectors.toList());
    }
}

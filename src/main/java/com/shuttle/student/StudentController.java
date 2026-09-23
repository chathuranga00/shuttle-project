package com.shuttle.student;

import com.shuttle.student.dto.StudentCardResponse;
import com.shuttle.student.dto.StudentProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
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

    private final StudentService studentService;

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
}

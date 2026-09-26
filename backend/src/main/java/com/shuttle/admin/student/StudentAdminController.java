package com.shuttle.admin.student;

import com.shuttle.domain.enums.UserStatus;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/students")
@RequiredArgsConstructor
@Tag(name = "Admin – Students", description = "Student account and profile administration")
@SecurityRequirement(name = "bearerAuth")
public class StudentAdminController {

    private final StudentAdminService studentAdminService;

    @GetMapping
    @Operation(summary = "List students with search, status filtering, and pagination")
    public Page<StudentAdminResponse> listStudents(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) UserStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        return studentAdminService.listStudents(search, status, pageable);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get student details by ID")
    public StudentAdminResponse getById(@PathVariable Long id) {
        return studentAdminService.getById(id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update student details")
    public StudentAdminResponse update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateStudentRequest request
    ) {
        return studentAdminService.updateStudent(id, request);
    }

    @PutMapping("/{id}/status")
    @Operation(summary = "Update student status (e.g. ACTIVE, SUSPENDED)")
    public StudentAdminResponse updateStatus(
            @PathVariable Long id,
            @Valid @RequestBody UpdateStudentStatusRequest request
    ) {
        return studentAdminService.updateStatus(id, request.status());
    }

    @PostMapping("/{id}/suspend")
    @Operation(summary = "Suspend a student account")
    public StudentAdminResponse suspend(@PathVariable Long id) {
        return studentAdminService.updateStatus(id, UserStatus.SUSPENDED);
    }

    @PostMapping("/{id}/activate")
    @Operation(summary = "Activate a student account")
    public StudentAdminResponse activate(@PathVariable Long id) {
        return studentAdminService.updateStatus(id, UserStatus.ACTIVE);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Deactivate/delete a student")
    public void delete(@PathVariable Long id) {
        studentAdminService.deleteStudent(id);
    }
}

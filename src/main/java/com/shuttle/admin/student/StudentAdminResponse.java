package com.shuttle.admin.student;

import java.time.Instant;

public record StudentAdminResponse(
        Long id,
        Long userId,
        String studentId,
        String fullName,
        String email,
        String phone,
        String faculty,
        String department,
        Integer enrollmentYear,
        String status,
        Instant createdAt
) {}

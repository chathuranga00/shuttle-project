package com.shuttle.student.dto;

public record StudentProfileResponse(
        Long userId,
        String email,
        String fullName,
        String phone,
        String studentId,
        String faculty,
        Integer enrollmentYear
) {}

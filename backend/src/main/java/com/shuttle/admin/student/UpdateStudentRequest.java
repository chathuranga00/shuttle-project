package com.shuttle.admin.student;

public record UpdateStudentRequest(
        String fullName,
        String phone,
        String faculty,
        String department,
        Integer enrollmentYear
) {}

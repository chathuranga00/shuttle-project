package com.shuttle.student.dto;

public record CardVerificationResponse(
        String studentName,
        String cardId,
        String cardStatus,
        String monthlyPassStatus
) {}

package com.shuttle.student;

/**
 * Result returned by {@link CardTokenService#verifyCardToken(String)}.
 * Contains only non-sensitive data safe to return to a driver or admin.
 */
public record CardVerificationResult(
        String studentName,
        String cardId,
        String cardStatus,
        String monthlyPassStatus
) {}

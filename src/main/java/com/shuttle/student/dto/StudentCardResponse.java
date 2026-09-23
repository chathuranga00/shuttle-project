package com.shuttle.student.dto;

public record StudentCardResponse(
        String cardId,
        String cardStatus,
        String monthlyPassStatus,
        WalletSummary wallet,
        String qrToken
) {}

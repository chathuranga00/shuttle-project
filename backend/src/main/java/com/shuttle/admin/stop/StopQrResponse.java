package com.shuttle.admin.stop;

/** Signed QR payload for a bus stop. */
public record StopQrResponse(
        Long   stopId,
        String qrCode,
        /** Signed payload: base64url(stopCode) + "." + base64url(hmac-sha256). */
        String signedPayload
) {}

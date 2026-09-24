package com.shuttle.admin.stop;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.shuttle.config.JwtProperties;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.enums.StopStatus;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.exception.ApiException;
import jakarta.annotation.PostConstruct;
import jakarta.persistence.EntityNotFoundException;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class BusStopService {

    private static final int QR_SIZE_PX = 300;

    private final BusStopRepository busStopRepository;
    private final JwtProperties     jwtProperties;

    private byte[] hmacKey;

    @PostConstruct
    void init() {
        hmacKey = jwtProperties.secret().getBytes(StandardCharsets.UTF_8);
    }

    // ── CRUD ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<BusStopResponse> listAll() {
        return busStopRepository.findAll().stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public BusStopResponse getById(Long id) {
        return toResponse(load(id));
    }

    @Transactional
    public BusStopResponse create(BusStopRequest req) {
        String code = resolveCode(req.qrCode(), null);
        if (busStopRepository.existsByQrCode(code)) {
            throw new ApiException(HttpStatus.CONFLICT, "STOP_CODE_EXISTS",
                    "QR code '" + code + "' is already in use.");
        }
        BusStop stop = new BusStop();
        apply(stop, req, code);
        return toResponse(busStopRepository.save(stop));
    }

    @Transactional
    public BusStopResponse update(Long id, BusStopRequest req) {
        BusStop stop = load(id);
        String code = resolveCode(req.qrCode(), stop.getQrCode());
        if (busStopRepository.existsByQrCodeAndIdNot(code, id)) {
            throw new ApiException(HttpStatus.CONFLICT, "STOP_CODE_EXISTS",
                    "QR code '" + code + "' is already used by another stop.");
        }
        apply(stop, req, code);
        return toResponse(busStopRepository.save(stop));
    }

    @Transactional
    public void delete(Long id) {
        busStopRepository.delete(load(id));
    }

    // ── QR payload & PNG ──────────────────────────────────────────────────────

    /** Returns the signed QR payload (no image). */
    @Transactional(readOnly = true)
    public StopQrResponse getQrPayload(Long id) {
        BusStop stop = load(id);
        return new StopQrResponse(stop.getId(), stop.getQrCode(), buildPayload(stop.getQrCode()));
    }

    /** Returns a PNG byte array of the signed QR code for the given stop. */
    @Transactional(readOnly = true)
    public byte[] getQrPng(Long id) {
        BusStop stop = load(id);
        String payload = buildPayload(stop.getQrCode());
        try {
            QRCodeWriter writer = new QRCodeWriter();
            Map<EncodeHintType, Object> hints = new EnumMap<>(EncodeHintType.class);
            hints.put(EncodeHintType.CHARACTER_SET, "UTF-8");
            hints.put(EncodeHintType.MARGIN, 2);
            BitMatrix matrix = writer.encode(payload, BarcodeFormat.QR_CODE,
                    QR_SIZE_PX, QR_SIZE_PX, hints);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            MatrixToImageWriter.writeToStream(matrix, "PNG", baos);
            return baos.toByteArray();
        } catch (WriterException | IOException ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "QR_GENERATION_FAILED", "Could not generate QR image.");
        }
    }

    /**
     * Verifies a scanned QR payload. Returns the stop if valid.
     * Payload format: {@code <stopCode>.<base64url(hmac)>}
     * Runs in REQUIRES_NEW so exceptions here never contaminate caller transactions.
     */
    @Transactional(readOnly = true, propagation = Propagation.REQUIRES_NEW, noRollbackFor = ApiException.class)
    public BusStop verifyQrPayload(String payload) {
        String[] parts = payload.split("\\.", 2);
        if (parts.length != 2) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QR", "Malformed QR payload.");
        }
        String stopCode  = parts[0];
        String givenMac  = parts[1];
        String expected  = computeHmac(stopCode);
        if (!expected.equals(givenMac)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "QR_SIGNATURE_INVALID",
                    "QR code signature is invalid.");
        }
        return busStopRepository.findByQrCode(stopCode)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "STOP_NOT_FOUND", "No stop found for QR code '" + stopCode + "'."));
    }

    // ── Package-visible mapper (used by RouteService) ─────────────────────────

    BusStopResponse toResponse(BusStop stop) {
        return new BusStopResponse(
                stop.getId(), stop.getName(), stop.getQrCode(),
                stop.getLatitude(), stop.getLongitude(), stop.getAddress(),
                stop.getStatus().name(), stop.getCreatedAt(), stop.getUpdatedAt());
    }

    BusStop load(Long id) {
        return busStopRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Bus stop " + id + " not found."));
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private String resolveCode(String requested, String existing) {
        if (requested != null && !requested.isBlank()) return requested.trim().toUpperCase();
        if (existing  != null && !existing.isBlank())  return existing;
        // Auto-generate: STOP-{count+1} padded to 3 digits
        long count = busStopRepository.count();
        return String.format("STOP-%03d", count + 1);
    }

    private void apply(BusStop stop, BusStopRequest req, String code) {
        stop.setName(req.name());
        stop.setQrCode(code);
        stop.setLatitude(req.latitude());
        stop.setLongitude(req.longitude());
        stop.setAddress(req.address());
        stop.setStatus(StopStatus.valueOf(req.status().toUpperCase()));
    }

    /** Builds the signed payload: {@code stopCode.base64url(hmac-sha256(stopCode))} */
    private String buildPayload(String stopCode) {
        return stopCode + "." + computeHmac(stopCode);
    }

    private String computeHmac(String input) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(hmacKey, "HmacSHA256"));
            byte[] raw = mac.doFinal(input.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        } catch (Exception ex) {
            throw new IllegalStateException("HMAC computation failed", ex);
        }
    }
}

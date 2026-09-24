package com.shuttle.admin.stop;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/stops")
@RequiredArgsConstructor
@Tag(name = "Admin – Bus Stops", description = "Bus stop management")
@SecurityRequirement(name = "bearerAuth")
public class BusStopAdminController {

    private final BusStopService busStopService;

    @GetMapping
    @Operation(summary = "List all bus stops")
    public List<BusStopResponse> listAll() { return busStopService.listAll(); }

    @GetMapping("/{id}")
    @Operation(summary = "Get bus stop by ID")
    public BusStopResponse getById(@PathVariable Long id) { return busStopService.getById(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a new bus stop")
    public BusStopResponse create(@Valid @RequestBody BusStopRequest request) {
        return busStopService.create(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a bus stop")
    public BusStopResponse update(@PathVariable Long id, @Valid @RequestBody BusStopRequest request) {
        return busStopService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a bus stop")
    public void delete(@PathVariable Long id) { busStopService.delete(id); }

    @GetMapping("/{id}/qr")
    @Operation(summary = "Get the signed QR payload and PNG image for a stop")
    public ResponseEntity<byte[]> getQr(@PathVariable Long id) {
        byte[] png = busStopService.getQrPng(id);
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_PNG)
                .header("X-QR-Payload", busStopService.getQrPayload(id).signedPayload())
                .body(png);
    }

    @GetMapping("/{id}/qr/payload")
    @Operation(summary = "Get only the signed QR payload text (no image)")
    public StopQrResponse getQrPayload(@PathVariable Long id) {
        return busStopService.getQrPayload(id);
    }
}

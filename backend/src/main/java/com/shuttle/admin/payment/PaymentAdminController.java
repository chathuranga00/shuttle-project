package com.shuttle.admin.payment;

import com.shuttle.domain.enums.PaymentStatus;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/payments")
@RequiredArgsConstructor
@Tag(name = "Admin – Payments", description = "Payment transactions inspection and auditing")
@SecurityRequirement(name = "bearerAuth")
public class PaymentAdminController {

    private final PaymentAdminService paymentAdminService;

    @GetMapping
    @Operation(summary = "List payments with status, date range, search, and pagination")
    public Page<PaymentAdminResponse> listPayments(
            @RequestParam(required = false) PaymentStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        return paymentAdminService.listPayments(status, from, to, search, pageable);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get payment transaction details by ID")
    public PaymentAdminResponse getById(@PathVariable Long id) {
        return paymentAdminService.getById(id);
    }
}

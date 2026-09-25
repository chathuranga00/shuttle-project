package com.shuttle.admin.report;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/reports")
@RequiredArgsConstructor
@Tag(name = "Admin – Reports", description = "Operational and financial reports generation (JSON and CSV)")
@SecurityRequirement(name = "bearerAuth")
public class AdminReportController {

    private final AdminReportService reportService;

    @GetMapping("/{type}")
    @Operation(summary = "Generate report in JSON or CSV format")
    public ResponseEntity<?> getReport(
            @PathVariable String type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "json") String format
    ) {
        ReportResponse report = reportService.generateReport(type, from, to);

        if ("csv".equalsIgnoreCase(format)) {
            byte[] csvBytes = reportService.toCsv(report);
            String filename = String.format("report-%s-%s-to-%s.csv", type, report.from(), report.to());

            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                    .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                    .body(csvBytes);
        }

        return ResponseEntity.ok(report);
    }
}

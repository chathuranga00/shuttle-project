package com.shuttle.admin.report;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record ReportResponse(
        String reportType,
        LocalDate from,
        LocalDate to,
        Instant generatedAt,
        List<String> headers,
        List<List<Object>> rows,
        Map<String, Object> summary
) {}

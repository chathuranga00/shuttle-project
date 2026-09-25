package com.shuttle.admin.report;

import com.shuttle.domain.entity.BoardingRecord;
import com.shuttle.domain.entity.BusStop;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Payment;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.Trip;
import com.shuttle.domain.enums.PaymentStatus;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.TripRepository;
import com.shuttle.exception.ApiException;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AdminReportService {

    private final BoardingRecordRepository boardingRecordRepository;
    private final PaymentRepository paymentRepository;
    private final TripRepository tripRepository;
    private final MonthlyPassRepository monthlyPassRepository;
    private final RouteRepository routeRepository;
    private final BusStopRepository busStopRepository;

    @Transactional(readOnly = true)
    public ReportResponse generateReport(String type, LocalDate from, LocalDate to) {
        if (from == null) {
            from = LocalDate.now(ZoneOffset.UTC).minusDays(30);
        }
        if (to == null) {
            to = LocalDate.now(ZoneOffset.UTC);
        }

        Instant fromInstant = from.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        return switch (type.toLowerCase()) {
            case "daily-passenger" -> generateDailyPassengerReport(from, to, fromInstant, toInstant);
            case "daily-revenue" -> generateDailyRevenueReport(from, to, fromInstant, toInstant);
            case "monthly-revenue" -> generateMonthlyRevenueReport(from, to, fromInstant, toInstant);
            case "route-usage" -> generateRouteUsageReport(from, to, fromInstant, toInstant);
            case "boarding-location" -> generateBoardingLocationReport(from, to, fromInstant, toInstant);
            case "monthly-pass" -> generateMonthlyPassReport(from, to);
            case "trip" -> generateTripReport(from, to, fromInstant, toInstant);
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_REPORT_TYPE",
                    "Unknown report type: " + type + ". Supported: daily-passenger, daily-revenue, monthly-revenue, route-usage, boarding-location, monthly-pass, trip");
        };
    }

    private ReportResponse generateDailyPassengerReport(LocalDate from, LocalDate to, Instant fromInstant, Instant toInstant) {
        List<BoardingRecord> records = boardingRecordRepository.findByBoardedAtBetween(fromInstant, toInstant);

        Map<LocalDate, List<BoardingRecord>> byDate = records.stream()
                .collect(Collectors.groupingBy(r -> r.getBoardedAt().atZone(ZoneOffset.UTC).toLocalDate()));

        List<String> headers = List.of("Date", "Total Passengers", "Monthly Pass", "Pay Per Trip");
        List<List<Object>> rows = new ArrayList<>();

        long grandTotal = 0;
        long totalPass = 0;
        long totalPaid = 0;

        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            List<BoardingRecord> dayList = byDate.getOrDefault(d, List.of());
            long total = dayList.size();
            long pass = dayList.stream().filter(r -> "PASS".equalsIgnoreCase(r.getPaymentStatus()) || r.getMonthlyPass() != null).count();
            long paid = total - pass;

            grandTotal += total;
            totalPass += pass;
            totalPaid += paid;

            rows.add(List.of(d.toString(), total, pass, paid));
        }

        Map<String, Object> summary = Map.of(
                "totalDays", rows.size(),
                "grandTotalPassengers", grandTotal,
                "totalPassBoardings", totalPass,
                "totalPayPerTripBoardings", totalPaid
        );

        return new ReportResponse("daily-passenger", from, to, Instant.now(), headers, rows, summary);
    }

    private ReportResponse generateDailyRevenueReport(LocalDate from, LocalDate to, Instant fromInstant, Instant toInstant) {
        List<Payment> payments = paymentRepository.findByCreatedAtBetween(fromInstant, toInstant).stream()
                .filter(p -> p.getStatus() == PaymentStatus.SUCCESS)
                .toList();

        Map<LocalDate, List<Payment>> byDate = payments.stream()
                .collect(Collectors.groupingBy(p -> p.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate()));

        List<String> headers = List.of("Date", "Total Revenue (LKR)", "Wallet Top-ups", "Pass Purchases", "Transactions");
        List<List<Object>> rows = new ArrayList<>();

        BigDecimal grandTotal = BigDecimal.ZERO;

        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            List<Payment> dayPayments = byDate.getOrDefault(d, List.of());
            BigDecimal dayTotal = dayPayments.stream()
                    .map(Payment::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal topups = dayPayments.stream()
                    .filter(p -> p.getType() != null && "WALLET_TOPUP".equals(p.getType().name()))
                    .map(Payment::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal passes = dayPayments.stream()
                    .filter(p -> p.getType() != null && "MONTHLY_PASS".equals(p.getType().name()))
                    .map(Payment::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            grandTotal = grandTotal.add(dayTotal);
            rows.add(List.of(d.toString(), dayTotal, topups, passes, dayPayments.size()));
        }

        Map<String, Object> summary = Map.of(
                "grandTotalRevenue", grandTotal,
                "totalTransactions", payments.size()
        );

        return new ReportResponse("daily-revenue", from, to, Instant.now(), headers, rows, summary);
    }

    private ReportResponse generateMonthlyRevenueReport(LocalDate from, LocalDate to, Instant fromInstant, Instant toInstant) {
        List<Payment> payments = paymentRepository.findByCreatedAtBetween(fromInstant, toInstant).stream()
                .filter(p -> p.getStatus() == PaymentStatus.SUCCESS)
                .toList();

        Map<YearMonth, List<Payment>> byMonth = payments.stream()
                .collect(Collectors.groupingBy(p -> YearMonth.from(p.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate()),
                        LinkedHashMap::new, Collectors.toList()));

        List<String> headers = List.of("Month", "Total Revenue (LKR)", "Transactions", "Average Transaction (LKR)");
        List<List<Object>> rows = new ArrayList<>();

        BigDecimal grandTotal = BigDecimal.ZERO;

        for (Map.Entry<YearMonth, List<Payment>> entry : byMonth.entrySet()) {
            YearMonth ym = entry.getKey();
            List<Payment> monthPayments = entry.getValue();

            BigDecimal total = monthPayments.stream()
                    .map(Payment::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            grandTotal = grandTotal.add(total);
            BigDecimal avg = monthPayments.isEmpty() ? BigDecimal.ZERO :
                    total.divide(BigDecimal.valueOf(monthPayments.size()), 2, java.math.RoundingMode.HALF_UP);

            rows.add(List.of(ym.toString(), total, monthPayments.size(), avg));
        }

        Map<String, Object> summary = Map.of(
                "grandTotalRevenue", grandTotal,
                "totalMonths", rows.size()
        );

        return new ReportResponse("monthly-revenue", from, to, Instant.now(), headers, rows, summary);
    }

    private ReportResponse generateRouteUsageReport(LocalDate from, LocalDate to, Instant fromInstant, Instant toInstant) {
        List<Route> routes = routeRepository.findAll();
        List<BoardingRecord> boardings = boardingRecordRepository.findByBoardedAtBetween(fromInstant, toInstant);

        Map<Long, Long> boardingsByRoute = boardings.stream()
                .collect(Collectors.groupingBy(b -> b.getTrip().getRoute().getId(), Collectors.counting()));

        List<String> headers = List.of("Route Code", "Route Name", "Status", "Total Passengers");
        List<List<Object>> rows = new ArrayList<>();

        long grandTotal = 0;
        for (Route r : routes) {
            long count = boardingsByRoute.getOrDefault(r.getId(), 0L);
            grandTotal += count;
            rows.add(List.of(r.getCode(), r.getName(), r.getStatus().name(), count));
        }

        Map<String, Object> summary = Map.of(
                "totalRoutes", routes.size(),
                "grandTotalPassengers", grandTotal
        );

        return new ReportResponse("route-usage", from, to, Instant.now(), headers, rows, summary);
    }

    private ReportResponse generateBoardingLocationReport(LocalDate from, LocalDate to, Instant fromInstant, Instant toInstant) {
        List<BusStop> stops = busStopRepository.findAll();
        List<BoardingRecord> boardings = boardingRecordRepository.findByBoardedAtBetween(fromInstant, toInstant);

        Map<Long, Long> byStop = boardings.stream()
                .collect(Collectors.groupingBy(b -> b.getBusStop().getId(), Collectors.counting()));

        List<String> headers = List.of("Stop Code", "Stop Name", "Status", "Total Boardings");
        List<List<Object>> rows = new ArrayList<>();

        long totalBoardings = 0;
        for (BusStop s : stops) {
            long count = byStop.getOrDefault(s.getId(), 0L);
            totalBoardings += count;
            rows.add(List.of(s.getQrCode(), s.getName(), s.getStatus().name(), count));
        }

        rows.sort((a, b) -> Long.compare((Long) b.get(3), (Long) a.get(3)));

        Map<String, Object> summary = Map.of(
                "totalStops", stops.size(),
                "grandTotalBoardings", totalBoardings
        );

        return new ReportResponse("boarding-location", from, to, Instant.now(), headers, rows, summary);
    }

    private ReportResponse generateMonthlyPassReport(LocalDate from, LocalDate to) {
        List<MonthlyPass> passes = monthlyPassRepository.findAll().stream()
                .filter(p -> !p.getValidFrom().isAfter(to) && !p.getValidTo().isBefore(from))
                .sorted(Comparator.comparing(MonthlyPass::getValidFrom).reversed())
                .toList();

        List<String> headers = List.of("Pass ID", "Student Name", "Student ID", "Route", "Price (LKR)", "Valid From", "Valid To", "Status");
        List<List<Object>> rows = new ArrayList<>();

        BigDecimal totalRevenue = BigDecimal.ZERO;
        for (MonthlyPass p : passes) {
            totalRevenue = totalRevenue.add(p.getPrice());
            rows.add(List.of(
                    p.getId(),
                    p.getStudent().getUser().getFullName(),
                    p.getStudent().getStudentId(),
                    p.getRoute() != null ? p.getRoute().getName() : "All Routes",
                    p.getPrice(),
                    p.getValidFrom().toString(),
                    p.getValidTo().toString(),
                    p.getStatus().name()
            ));
        }

        Map<String, Object> summary = Map.of(
                "totalPasses", passes.size(),
                "totalPassRevenue", totalRevenue
        );

        return new ReportResponse("monthly-pass", from, to, Instant.now(), headers, rows, summary);
    }

    private ReportResponse generateTripReport(LocalDate from, LocalDate to, Instant fromInstant, Instant toInstant) {
        List<Trip> trips = tripRepository.findAll().stream()
                .filter(t -> {
                    Instant s = t.getActualStart() != null ? t.getActualStart() :
                            (t.getScheduledStart() != null ? t.getScheduledStart() : t.getCreatedAt());
                    return s != null && !s.isBefore(fromInstant) && s.isBefore(toInstant);
                })
                .sorted(Comparator.comparing(Trip::getScheduledStart, Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();

        List<String> headers = List.of("Trip ID", "Route", "Bus", "Driver", "Status", "Scheduled Start", "Actual Start", "Actual End", "Passengers");
        List<List<Object>> rows = new ArrayList<>();

        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(ZoneOffset.UTC);

        long totalPassengers = 0;
        for (Trip t : trips) {
            long pCount = boardingRecordRepository.findByTripId(t.getId()).size();
            totalPassengers += pCount;

            rows.add(List.of(
                    t.getId(),
                    t.getRoute().getName(),
                    t.getBus().getBusNumber(),
                    t.getDriver().getUser().getFullName(),
                    t.getStatus().name(),
                    t.getScheduledStart() != null ? dtf.format(t.getScheduledStart()) : "",
                    t.getActualStart() != null ? dtf.format(t.getActualStart()) : "",
                    t.getActualEnd() != null ? dtf.format(t.getActualEnd()) : "",
                    pCount
            ));
        }

        Map<String, Object> summary = Map.of(
                "totalTrips", trips.size(),
                "grandTotalPassengers", totalPassengers
        );

        return new ReportResponse("trip", from, to, Instant.now(), headers, rows, summary);
    }

    public byte[] toCsv(ReportResponse report) {
        StringBuilder sb = new StringBuilder();

        // Header row
        sb.append(report.headers().stream()
                .map(this::escapeCsv)
                .collect(Collectors.joining(",")))
                .append("\r\n");

        // Data rows
        for (List<Object> row : report.rows()) {
            sb.append(row.stream()
                    .map(val -> escapeCsv(val != null ? val.toString() : ""))
                    .collect(Collectors.joining(",")))
                    .append("\r\n");
        }

        return sb.toString().getBytes(StandardCharsets.UTF_8);
    }

    private String escapeCsv(String val) {
        if (val == null) return "";
        if (val.contains(",") || val.contains("\"") || val.contains("\n") || val.contains("\r")) {
            return "\"" + val.replace("\"", "\"\"") + "\"";
        }
        return val;
    }
}

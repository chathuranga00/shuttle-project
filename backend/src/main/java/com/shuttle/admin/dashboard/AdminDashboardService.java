package com.shuttle.admin.dashboard;

import com.shuttle.domain.enums.TripStatus;
import com.shuttle.domain.repository.BoardingRecordRepository;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.BusStopRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.PaymentRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.TripRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AdminDashboardService {

    private final StudentRepository studentRepository;
    private final DriverRepository driverRepository;
    private final BusRepository busRepository;
    private final TripRepository tripRepository;
    private final BoardingRecordRepository boardingRecordRepository;
    private final PaymentRepository paymentRepository;
    private final MonthlyPassRepository monthlyPassRepository;
    private final RouteRepository routeRepository;
    private final BusStopRepository busStopRepository;

    @Transactional(readOnly = true)
    public AdminDashboardResponse getDashboardStats() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        Instant startOfDay = today.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant endOfDay = today.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        long totalStudents = studentRepository.count();
        long totalDrivers = driverRepository.count();
        long totalBuses = busRepository.count();
        long activeTrips = tripRepository.countByStatus(TripStatus.IN_PROGRESS);
        long todayPassengers = boardingRecordRepository.countByBoardedAtBetween(startOfDay, endOfDay);
        BigDecimal todayRevenue = paymentRepository.sumRevenueBetween(startOfDay, endOfDay);
        if (todayRevenue == null) {
            todayRevenue = BigDecimal.ZERO;
        }
        long activeMonthlyPasses = monthlyPassRepository.countActivePasses(today);
        long totalRoutes = routeRepository.count();
        long totalStops = busStopRepository.count();

        return new AdminDashboardResponse(
                totalStudents,
                totalDrivers,
                totalBuses,
                activeTrips,
                todayPassengers,
                todayRevenue,
                activeMonthlyPasses,
                totalRoutes,
                totalStops
        );
    }
}

package com.shuttle.pass;

import com.shuttle.domain.repository.MonthlyPassRepository;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Nightly job that transitions ACTIVE passes whose {@code validTo} is in the past
 * to EXPIRED status.
 *
 * <p>Runs at 00:05 every day (5 minutes past midnight UTC) to avoid conflicts
 * with any midnight traffic.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PassExpiryJob {

    private final MonthlyPassRepository monthlyPassRepository;

    @Scheduled(cron = "0 5 0 * * *")   // 00:05 UTC daily
    @Transactional
    public void expireOldPasses() {
        LocalDate today   = LocalDate.now();
        int expired       = monthlyPassRepository.expirePassesBefore(today);
        if (expired > 0) {
            log.info("PassExpiryJob: marked {} pass(es) as EXPIRED (before {}).",
                    expired, today);
        }
    }
}

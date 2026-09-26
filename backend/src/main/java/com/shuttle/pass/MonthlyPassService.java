package com.shuttle.pass;

import com.shuttle.admin.settings.SystemSettingsService;
import com.shuttle.config.PassProperties;
import com.shuttle.domain.entity.MonthlyPass;
import com.shuttle.domain.entity.Student;
import com.shuttle.domain.enums.PassStatus;
import com.shuttle.domain.repository.MonthlyPassRepository;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.exception.ApiException;
import com.shuttle.pass.dto.PassListItem;
import com.shuttle.pass.dto.PassStatusResponse;
import com.shuttle.pass.dto.PurchasePassRequest;
import com.shuttle.security.UserPrincipal;
import jakarta.persistence.EntityNotFoundException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class MonthlyPassService {

    private final MonthlyPassRepository  monthlyPassRepository;
    private final StudentRepository      studentRepository;
    private final SystemSettingsService  settingsService;
    private final PassProperties         passProperties;

    // ── List all passes ───────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<PassListItem> listPasses(Authentication auth) {
        Student student = resolveStudent(auth);
        return monthlyPassRepository.findByStudentId(student.getId())
                .stream()
                .map(this::toListItem)
                .collect(Collectors.toList());
    }

    // ── Current status ────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public PassStatusResponse getStatus(Authentication auth) {
        Student student  = resolveStudent(auth);
        LocalDate today  = LocalDate.now();
        BigDecimal price = settingsService.getMonthlyPassPrice();

        // Find latest non-cancelled pass
        List<MonthlyPass> passes = monthlyPassRepository.findByStudentId(student.getId());
        MonthlyPass latest = passes.stream()
                .filter(p -> p.getStatus() != PassStatus.CANCELLED)
                .max((a, b) -> a.getValidFrom().compareTo(b.getValidFrom()))
                .orElse(null);

        if (latest == null) {
            return new PassStatusResponse(null, "NONE", null, null, null, false, price);
        }

        boolean coveringToday = latest.getStatus() == PassStatus.ACTIVE
                && !today.isBefore(latest.getValidFrom())
                && !today.isAfter(latest.getValidTo());

        return new PassStatusResponse(
                latest.getId(),
                latest.getStatus().name(),
                latest.getValidFrom(),
                latest.getValidTo(),
                latest.getPrice(),
                coveringToday,
                price);
    }

    // ── Purchase ──────────────────────────────────────────────────────────────

    /**
     * Purchases a one-month pass starting from {@code validFrom} (defaults to today).
     *
     * <p>In the dev mock-paid flow ({@code app.pass.mock-paid-enabled=true}) the pass
     * is created directly as ACTIVE. In production it would start as PENDING until the
     * payment gateway calls back.
     *
     * <p>Prevents purchasing when an overlapping ACTIVE or PENDING pass already exists.
     */
    @Transactional
    public PassStatusResponse purchase(PurchasePassRequest req, Authentication auth) {
        Student student  = resolveStudent(auth);
        LocalDate from   = req.validFrom() != null ? req.validFrom() : LocalDate.now();
        LocalDate to     = from.plusMonths(1).minusDays(1);
        BigDecimal price = settingsService.getMonthlyPassPrice();

        // Prevent overlapping active/pending passes
        if (monthlyPassRepository.existsOverlappingPass(student.getId(), from, to)) {
            throw new ApiException(HttpStatus.CONFLICT, "PASS_OVERLAP",
                    "You already have an active or pending pass that covers this period.");
        }

        MonthlyPass pass = new MonthlyPass();
        pass.setStudent(student);
        pass.setValidFrom(from);
        pass.setValidTo(to);
        pass.setPrice(price);

        if (passProperties.mockPaidEnabled()) {
            // Dev-only: treat purchase as immediately paid and active
            pass.setStatus(PassStatus.ACTIVE);
        } else {
            // Prod: start PENDING, awaiting payment confirmation
            pass.setStatus(PassStatus.PENDING);
        }

        monthlyPassRepository.save(pass);

        LocalDate today = LocalDate.now();
        boolean coveringToday = pass.getStatus() == PassStatus.ACTIVE
                && !today.isBefore(from) && !today.isAfter(to);

        return new PassStatusResponse(
                pass.getId(),
                pass.getStatus().name(),
                from, to, price, coveringToday, price);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private Student resolveStudent(Authentication auth) {
        UserPrincipal principal = (UserPrincipal) auth.getPrincipal();
        return studentRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new EntityNotFoundException("Student profile not found."));
    }

    private PassListItem toListItem(MonthlyPass p) {
        return new PassListItem(
                p.getId(), p.getStatus().name(),
                p.getValidFrom(), p.getValidTo(),
                p.getPrice(), p.getCreatedAt());
    }
}

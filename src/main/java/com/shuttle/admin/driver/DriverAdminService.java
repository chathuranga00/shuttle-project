package com.shuttle.admin.driver;

import com.shuttle.domain.entity.Bus;
import com.shuttle.domain.entity.Driver;
import com.shuttle.domain.entity.DriverBusAssignment;
import com.shuttle.domain.entity.Route;
import com.shuttle.domain.entity.User;
import com.shuttle.domain.enums.DriverStatus;
import com.shuttle.domain.enums.Role;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.BusRepository;
import com.shuttle.domain.repository.DriverBusAssignmentRepository;
import com.shuttle.domain.repository.DriverRepository;
import com.shuttle.domain.repository.RouteRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.exception.ApiException;
import jakarta.persistence.EntityNotFoundException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DriverAdminService {

    private final UserRepository               userRepository;
    private final DriverRepository             driverRepository;
    private final BusRepository                busRepository;
    private final RouteRepository              routeRepository;
    private final DriverBusAssignmentRepository assignmentRepository;
    private final PasswordEncoder              passwordEncoder;

    @Transactional(readOnly = true)
    public List<DriverResponse> listAll() {
        return driverRepository.findAll().stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public DriverResponse getById(Long driverId) {
        return toResponse(load(driverId));
    }

    @Transactional
    public DriverResponse create(CreateDriverRequest req) {
        if (userRepository.existsByEmail(req.email().toLowerCase())) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_EXISTS",
                    "A user with this email already exists.");
        }
        if (driverRepository.findByLicenseNumber(req.licenseNumber()).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "LICENSE_EXISTS",
                    "License number '" + req.licenseNumber() + "' is already registered.");
        }

        User user = new User();
        user.setEmail(req.email().toLowerCase());
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setFullName(req.fullName());
        user.setPhone(req.phone());
        user.setRole(Role.DRIVER);
        user.setStatus(UserStatus.ACTIVE);
        userRepository.save(user);

        Driver driver = new Driver();
        driver.setUser(user);
        driver.setLicenseNumber(req.licenseNumber());
        driver.setLicenseExpiry(req.licenseExpiry());
        driver.setStatus(DriverStatus.ACTIVE);
        driverRepository.save(driver);

        if (req.busId() != null) {
            createAssignment(driver, req.busId(), req.routeId());
        }

        return toResponse(driver);
    }

    @Transactional
    public DriverResponse update(Long driverId, UpdateDriverRequest req) {
        Driver driver = load(driverId);
        if (!driver.getLicenseNumber().equals(req.licenseNumber())
                && driverRepository.findByLicenseNumber(req.licenseNumber()).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "LICENSE_EXISTS",
                    "License number '" + req.licenseNumber() + "' is already registered.");
        }
        driver.setLicenseNumber(req.licenseNumber());
        driver.setLicenseExpiry(req.licenseExpiry());
        driver.setStatus(DriverStatus.valueOf(req.status().toUpperCase()));
        return toResponse(driverRepository.save(driver));
    }

    @Transactional
    public DriverResponse assign(Long driverId, AssignDriverRequest req) {
        Driver driver = load(driverId);
        assignmentRepository.closeAssignmentsForDriver(driverId, Instant.now());
        createAssignment(driver, req.busId(), req.routeId());
        return toResponse(driver);
    }

    @Transactional
    public DriverResponse unassign(Long driverId) {
        load(driverId); // validate exists
        assignmentRepository.closeAssignmentsForDriver(driverId, Instant.now());
        return toResponse(load(driverId));
    }

    @Transactional
    public void delete(Long driverId) {
        Driver driver = load(driverId);
        driver.setStatus(DriverStatus.INACTIVE);
        driver.getUser().setStatus(com.shuttle.domain.enums.UserStatus.INACTIVE);
        assignmentRepository.closeAssignmentsForDriver(driverId, Instant.now());
        driverRepository.save(driver);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private Driver load(Long id) {
        return driverRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Driver " + id + " not found."));
    }

    private void createAssignment(Driver driver, Long busId, Long routeId) {
        Bus bus = busRepository.findById(busId)
                .orElseThrow(() -> new EntityNotFoundException("Bus " + busId + " not found."));
        Route route = null;
        if (routeId != null) {
            route = routeRepository.findById(routeId)
                    .orElseThrow(() -> new EntityNotFoundException("Route " + routeId + " not found."));
        }
        DriverBusAssignment assignment = new DriverBusAssignment();
        assignment.setDriver(driver);
        assignment.setBus(bus);
        assignment.setRoute(route);
        assignment.setAssignedAt(Instant.now());
        assignmentRepository.save(assignment);
    }

    private DriverResponse toResponse(Driver driver) {
        Optional<DriverBusAssignment> current =
                assignmentRepository.findCurrentByDriverId(driver.getId());
        return new DriverResponse(
                driver.getId(),
                driver.getUser().getId(),
                driver.getUser().getFullName(),
                driver.getUser().getEmail(),
                driver.getUser().getPhone(),
                driver.getLicenseNumber(),
                driver.getLicenseExpiry(),
                driver.getStatus().name(),
                driver.getUser().getStatus().name(),
                current.map(a -> a.getBus().getId()).orElse(null),
                current.map(a -> a.getBus().getBusNumber()).orElse(null),
                current.map(a -> a.getRoute() != null ? a.getRoute().getId() : null).orElse(null),
                current.map(a -> a.getRoute() != null ? a.getRoute().getName() : null).orElse(null),
                driver.getCreatedAt());
    }
}

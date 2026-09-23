package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Driver;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DriverRepository extends JpaRepository<Driver, Long> {
    Optional<Driver> findByUserId(Long userId);
    Optional<Driver> findByLicenseNumber(String licenseNumber);
}

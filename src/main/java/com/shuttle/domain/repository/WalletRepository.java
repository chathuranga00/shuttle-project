package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Wallet;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WalletRepository extends JpaRepository<Wallet, Long> {
    Optional<Wallet> findByStudentId(Long studentId);
}

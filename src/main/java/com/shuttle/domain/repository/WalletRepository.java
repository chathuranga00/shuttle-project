package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Wallet;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WalletRepository extends JpaRepository<Wallet, Long> {

    Optional<Wallet> findByStudentId(Long studentId);

    /**
     * Loads a wallet with a PESSIMISTIC_WRITE lock (SELECT … FOR UPDATE).
     * Use this inside a @Transactional method when deducting balance to prevent
     * concurrent boardings from over-drawing the wallet.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT w FROM Wallet w WHERE w.student.id = :studentId")
    Optional<Wallet> findByStudentIdWithLock(@Param("studentId") Long studentId);
}

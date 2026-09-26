package com.shuttle.domain.repository;

import com.shuttle.domain.entity.WalletTransaction;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WalletTransactionRepository extends JpaRepository<WalletTransaction, Long> {
    List<WalletTransaction> findByWalletIdOrderByCreatedAtDesc(Long walletId);
}

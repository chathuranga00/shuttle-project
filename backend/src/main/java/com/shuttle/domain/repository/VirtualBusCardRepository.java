package com.shuttle.domain.repository;

import com.shuttle.domain.entity.VirtualBusCard;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VirtualBusCardRepository extends JpaRepository<VirtualBusCard, Long> {
    Optional<VirtualBusCard> findByCardId(String cardId);
    Optional<VirtualBusCard> findByStudentId(Long studentId);
    boolean existsByCardId(String cardId);
}

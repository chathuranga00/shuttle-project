package com.shuttle.domain.entity;

import com.shuttle.domain.enums.CardStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(
        name = "virtual_bus_cards",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_virtual_bus_cards_student_id", columnNames = "student_id"),
                @UniqueConstraint(name = "uk_virtual_bus_cards_card_id", columnNames = "card_id")
        },
        indexes = @Index(name = "idx_virtual_bus_cards_status", columnList = "status")
)
public class VirtualBusCard extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id", nullable = false, unique = true)
    private Student student;

    @Column(name = "card_id", nullable = false, unique = true, length = 64)
    private String cardId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private CardStatus status = CardStatus.ACTIVE;

    @Column(name = "issued_at", nullable = false)
    private Instant issuedAt;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Column(name = "qr_payload", length = 255)
    private String qrPayload;
}

package com.shuttle.domain.entity;

import com.shuttle.domain.enums.PaymentMethod;
import com.shuttle.domain.enums.PaymentStatus;
import com.shuttle.domain.enums.PaymentType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "payments")
public class Payment extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id", nullable = false)
    private Student student;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private PaymentStatus status = PaymentStatus.PENDING;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private PaymentType type;

    @Enumerated(EnumType.STRING)
    @Column(length = 32)
    private PaymentMethod method;

    @Column(name = "provider_reference", unique = true, length = 100)
    private String providerReference;

    @Column(length = 255)
    private String description;

    /** Unique ID assigned by the payment gateway — used for idempotent webhook handling. */
    @Column(name = "gateway_transaction_id", unique = true, length = 128)
    private String gatewayTransactionId;

    /** Redirect URL returned by the gateway at checkout creation. */
    @Column(name = "checkout_url", length = 500)
    private String checkoutUrl;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "monthly_pass_id")
    private MonthlyPass monthlyPass;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "boarding_record_id")
    private BoardingRecord boardingRecord;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wallet_transaction_id")
    private WalletTransaction walletTransaction;
}

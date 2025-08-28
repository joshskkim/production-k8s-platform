package com.trading.payments.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "merchant_risk_profiles")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MerchantRiskProfile {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;
    
    @Column(name = "merchant_id", unique = true, nullable = false)
    private String merchantId;
    
    @Column(name = "daily_limit", precision = 12, scale = 2)
    private BigDecimal dailyLimit;
    
    @Column(name = "monthly_limit", precision = 15, scale = 2)
    private BigDecimal monthlyLimit;
    
    @Column(name = "transaction_count_limit")
    private Integer transactionCountLimit;
    
    @Column(name = "max_single_transaction", precision = 10, scale = 2)
    private BigDecimal maxSingleTransaction;
    
    @Column(name = "risk_tolerance")
    @Enumerated(EnumType.STRING)
    private RiskTolerance riskTolerance = RiskTolerance.MEDIUM;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
    
    @Column(name = "created_at")
    @CreationTimestamp
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

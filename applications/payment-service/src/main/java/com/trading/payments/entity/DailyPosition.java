package com.trading.payments.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "daily_positions", 
       uniqueConstraints = @UniqueConstraint(columnNames = {"merchant_id", "position_date"}))
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DailyPosition {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;
    
    @Column(name = "merchant_id", nullable = false)
    private String merchantId;
    
    @Column(name = "position_date", nullable = false)
    private LocalDate positionDate;
    
    @Column(name = "total_volume", precision = 15, scale = 2)
    private BigDecimal totalVolume = BigDecimal.ZERO;
    
    @Column(name = "transaction_count")
    private Integer transactionCount = 0;
    
    @Column(name = "approved_volume", precision = 15, scale = 2)
    private BigDecimal approvedVolume = BigDecimal.ZERO;
    
    @Column(name = "approved_count")
    private Integer approvedCount = 0;
    
    @Column(name = "declined_volume", precision = 15, scale = 2)
    private BigDecimal declinedVolume = BigDecimal.ZERO;
    
    @Column(name = "declined_count")
    private Integer declinedCount = 0;
    
    @Column(name = "avg_fraud_score", precision = 5, scale = 2)
    private BigDecimal avgFraudScore = BigDecimal.ZERO;
    
    @Column(name = "max_single_transaction", precision = 10, scale = 2)
    private BigDecimal maxSingleTransaction = BigDecimal.ZERO;
    
    @Column(name = "risk_exposure_pct", precision = 5, scale = 2)
    private BigDecimal riskExposurePercent = BigDecimal.ZERO;
    
    @Column(name = "created_at")
    @CreationTimestamp
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

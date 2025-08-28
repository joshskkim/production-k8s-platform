package com.trading.payments.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "risk_alerts")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RiskAlert {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;
    
    @Column(name = "merchant_id", nullable = false)
    private String merchantId;
    
    @Column(name = "alert_type", nullable = false)
    @Enumerated(EnumType.STRING)
    private AlertType alertType;
    
    @Column(name = "alert_level", nullable = false)
    @Enumerated(EnumType.STRING)
    private AlertLevel alertLevel;
    
    @Column(name = "threshold_value", precision = 15, scale = 2)
    private BigDecimal thresholdValue;
    
    @Column(name = "current_value", precision = 15, scale = 2)
    private BigDecimal currentValue;
    
    @Column(name = "message", columnDefinition = "TEXT")
    private String message;
    
    @Column(name = "transaction_id")
    private String transactionId;  // Triggering transaction
    
    @Column(name = "is_resolved")
    private Boolean isResolved = false;
    
    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;
    
    @Column(name = "created_at")
    @CreationTimestamp
    private LocalDateTime createdAt;
}
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
@Table(name = "fraud_rules")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FraudRule {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "rule_name", nullable = false)
    private String ruleName;
    
    @Column(name = "rule_type", nullable = false)
    private String ruleType;
    
    @Column(name = "threshold_value", precision = 10, scale = 2)
    private BigDecimal thresholdValue;
    
    @Column(name = "time_window_minutes")
    private Integer timeWindowMinutes;
    
    @Column(name = "risk_score")
    private Integer riskScore;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
    
    @Column(name = "created_at")
    @CreationTimestamp
    private LocalDateTime createdAt;
}

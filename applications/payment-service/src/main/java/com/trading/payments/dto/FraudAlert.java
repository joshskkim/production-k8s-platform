package com.trading.payments.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FraudAlert {
    private String transactionId;
    private String merchantId;
    private BigDecimal amount;
    private Integer fraudScore;
    private String riskLevel;  // LOW, MEDIUM, HIGH, CRITICAL
    private String message;
    private Instant timestamp;
}

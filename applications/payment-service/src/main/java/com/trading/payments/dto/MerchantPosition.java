package com.trading.payments.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MerchantPosition {
    private String merchantId;
    private String merchantName;
    private LocalDate positionDate;
    private BigDecimal totalVolume;
    private Integer transactionCount;
    private BigDecimal approvedVolume;
    private BigDecimal riskExposurePercent;
    private BigDecimal dailyLimit;
    private BigDecimal remainingLimit;
    private String riskTolerance;
    private Integer activeAlerts;
}

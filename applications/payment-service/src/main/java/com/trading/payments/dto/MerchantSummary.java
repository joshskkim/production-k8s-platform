package com.trading.payments.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MerchantSummary {
    private String merchantId;
    private Long totalTransactions;
    private BigDecimal totalAmount;
    private Long approvedCount;
    private Long declinedCount;
    private Double approvalRate;
    private Double averageFraudScore;
}

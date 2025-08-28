package com.trading.payments.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PositionSummary {
    private BigDecimal totalVolume;
    private Integer totalTransactions;
    private BigDecimal approvedVolume;
    private BigDecimal approvalRate;
    private Integer activeAlerts;
    private Integer merchantCount;
    private LocalDateTime timestamp;
}

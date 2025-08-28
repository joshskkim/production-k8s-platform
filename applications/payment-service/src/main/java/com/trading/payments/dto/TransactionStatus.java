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
public class TransactionStatus {
    private String transactionId;
    private String status;
    private BigDecimal amount;
    private Integer fraudScore;
    private LocalDateTime processedAt;
}

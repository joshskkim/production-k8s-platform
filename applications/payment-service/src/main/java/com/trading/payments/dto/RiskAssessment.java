package com.trading.payments.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RiskAssessment {
    private Boolean approved;
    private String reason;
    private Integer riskScore;
    private String merchantId;
    private Integer exposurePercent;
    
    public static RiskAssessment approved(String reason, Integer exposurePercent) {
        return RiskAssessment.builder()
            .approved(true)
            .reason(reason)
            .riskScore(0)
            .exposurePercent(exposurePercent)
            .build();
    }
    
    public static RiskAssessment blocked(String reason) {
        return RiskAssessment.builder()
            .approved(false)
            .reason(reason)
            .riskScore(100)
            .exposurePercent(0)
            .build();
    }
}

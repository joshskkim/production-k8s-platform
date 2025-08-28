package com.trading.payments.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PaymentRequest {
    @NotBlank 
    private String merchantId;
    
    @NotBlank 
    private String cardNumber;
    
    @NotNull 
    @DecimalMin("0.01") 
    private BigDecimal amount;
    
    private String currency = "USD";
    private String customerIp;
    private String userAgent;
}

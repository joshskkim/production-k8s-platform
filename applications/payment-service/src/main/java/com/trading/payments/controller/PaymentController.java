package com.trading.payments.controller;

import com.trading.payments.service.PaymentService;
import com.trading.payments.service.FraudDetectionService;
import com.trading.payments.dto.*;
import com.trading.payments.entity.Transaction;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.apache.commons.codec.digest.DigestUtils;

import jakarta.validation.Valid;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/payments")
@Slf4j
public class PaymentController {
    
    @Autowired private PaymentService paymentService;
    @Autowired private FraudDetectionService fraudService;
    
    // Health check endpoint
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "UP");
        status.put("service", "payment-api");
        status.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(status);
    }
    
    // Process payment endpoint
    @PostMapping("/process")
    public ResponseEntity<PaymentResponse> processPayment(@Valid @RequestBody PaymentRequest request) {
        try {
            log.info("Processing payment for merchant: {} amount: {}", request.getMerchantId(), request.getAmount());
            
            // Generate transaction ID
            String transactionId = "TXN_" + System.currentTimeMillis() + "_" + 
                                  UUID.randomUUID().toString().substring(0, 8).toUpperCase();
            
            // Basic validation
            if (request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
                return ResponseEntity.badRequest()
                    .body(PaymentResponse.builder()
                        .transactionId(transactionId)
                        .status("DECLINED")
                        .message("Invalid amount")
                        .build());
            }
            
            // Fraud detection check
            FraudResult fraudResult = fraudService.evaluateTransaction(request);
            
            // Determine transaction status based on fraud score
            String status = fraudResult.getRiskScore() > 50 ? "DECLINED" : "APPROVED";
            
            // Save transaction to database
            Transaction transaction = Transaction.builder()
                .transactionId(transactionId)
                .merchantId(request.getMerchantId())
                .cardNumberHash(hashCardNumber(request.getCardNumber()))
                .amount(request.getAmount())
                .currency(request.getCurrency())
                .status(status.toLowerCase())
                .fraudScore(fraudResult.getRiskScore())
                .customerIp(request.getCustomerIp())
                .userAgent(request.getUserAgent())
                .build();
            
            paymentService.saveTransaction(transaction);
            
            // Build response
            PaymentResponse response = PaymentResponse.builder()
                .transactionId(transactionId)
                .status(status)
                .fraudScore(fraudResult.getRiskScore())
                .amount(request.getAmount())
                .currency(request.getCurrency())
                .message(status.equals("APPROVED") ? "Payment approved" : "Payment declined - high fraud risk")
                .processedAt(Instant.now())
                .build();
                
            log.info("Payment processed: {} status: {} fraud_score: {}", 
                    transactionId, status, fraudResult.getRiskScore());
                    
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Payment processing failed: ", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(PaymentResponse.builder()
                    .status("FAILED")
                    .message("Internal processing error")
                    .build());
        }
    }
    
    // Get transaction status
    @GetMapping("/status/{transactionId}")
    public ResponseEntity<TransactionStatus> getTransactionStatus(@PathVariable String transactionId) {
        Optional<Transaction> transaction = paymentService.findByTransactionId(transactionId);
        
        if (transaction.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        
        TransactionStatus status = TransactionStatus.builder()
            .transactionId(transactionId)
            .status(transaction.get().getStatus().toUpperCase())
            .amount(transaction.get().getAmount())
            .fraudScore(transaction.get().getFraudScore())
            .processedAt(transaction.get().getCreatedAt())
            .build();
            
        return ResponseEntity.ok(status);
    }
    
    // Get merchant transaction summary
    @GetMapping("/merchant/{merchantId}/summary")
    public ResponseEntity<MerchantSummary> getMerchantSummary(
            @PathVariable String merchantId,
            @RequestParam(defaultValue = "24") int hours) {
        
        MerchantSummary summary = paymentService.getMerchantSummary(merchantId, hours);
        return ResponseEntity.ok(summary);
    }
    
    private String hashCardNumber(String cardNumber) {
        // Simple hash for demo - in production use proper PCI-compliant tokenization
        return DigestUtils.sha256Hex(cardNumber + "SALT_KEY");
    }
}

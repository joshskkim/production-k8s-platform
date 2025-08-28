package com.trading.payments;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.trading.payments.dto.PaymentRequest;
import com.trading.payments.dto.PaymentResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
public class PaymentProcessingIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine")
            .withDatabaseName("trading_platform_test")
            .withUsername("testuser")
            .withPassword("testpass");

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
            .withExposedPorts(6379);

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    public void testHealthEndpoint() throws Exception {
        mockMvc.perform(get("/api/v1/payments/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.service").value("payment-api"));
    }

    @Test
    public void testPaymentProcessing_NormalTransaction() throws Exception {
        PaymentRequest request = PaymentRequest.builder()
                .merchantId("MERCHANT_001")
                .cardNumber("4111111111111111")
                .amount(new BigDecimal("100.00"))
                .currency("USD")
                .customerIp("192.168.1.1")
                .userAgent("IntegrationTest/1.0")
                .build();

        MvcResult result = mockMvc.perform(post("/api/v1/payments/process")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.transactionId").exists())
                .andExpect(jsonPath("$.amount").value(100.00))
                .andExpect(jsonPath("$.currency").value("USD"))
                .andReturn();

        String responseJson = result.getResponse().getContentAsString();
        PaymentResponse response = objectMapper.readValue(responseJson, PaymentResponse.class);

        assertNotNull(response.getTransactionId());
        assertTrue(response.getStatus().equals("APPROVED") || 
                  response.getStatus().equals("DECLINED") || 
                  response.getStatus().equals("BLOCKED"));
        assertNotNull(response.getProcessedAt());
    }

    @Test
    public void testPaymentProcessing_HighAmountTransaction() throws Exception {
        PaymentRequest request = PaymentRequest.builder()
                .merchantId("MERCHANT_001")
                .cardNumber("4111111111111111")
                .amount(new BigDecimal("2000.00")) // High amount
                .currency("USD")
                .customerIp("192.168.1.1")
                .userAgent("IntegrationTest/1.0")
                .build();

        mockMvc.perform(post("/api/v1/payments/process")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.transactionId").exists())
                .andExpect(jsonPath("$.fraudScore").exists());
    }

    @Test
    public void testPaymentProcessing_InvalidAmount() throws Exception {
        PaymentRequest request = PaymentRequest.builder()
                .merchantId("MERCHANT_001")
                .cardNumber("4111111111111111")
                .amount(new BigDecimal("-10.00")) // Invalid amount
                .currency("USD")
                .customerIp("192.168.1.1")
                .userAgent("IntegrationTest/1.0")
                .build();

        mockMvc.perform(post("/api/v1/payments/process")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value("DECLINED"))
                .andExpect(jsonPath("$.message").value("must be greater than or equal to 0.01"));
    }

    @Test
    public void testRiskManagement_PortfolioSummary() throws Exception {
        mockMvc.perform(get("/api/v1/payments/risk/portfolio/summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalVolume").exists())
                .andExpect(jsonPath("$.totalTransactions").exists())
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    public void testRiskManagement_MerchantPosition() throws Exception {
        mockMvc.perform(get("/api/v1/payments/risk/merchant/MERCHANT_001/position"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.merchantId").value("MERCHANT_001"))
                .andExpect(jsonPath("$.positionDate").exists());
    }

    @Test
    public void testTransactionStatus_NotFound() throws Exception {
        mockMvc.perform(get("/api/v1/payments/status/NONEXISTENT_TXN"))
                .andExpect(status().isNotFound());
    }

    @Test
    public void testMerchantSummary() throws Exception {
        mockMvc.perform(get("/api/v1/payments/merchant/MERCHANT_001/summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.merchantId").value("MERCHANT_001"));
    }
}

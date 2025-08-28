package com.trading.payments.entity;

public enum AlertType {
    DAILY_LIMIT_APPROACHED,    // 80% of daily limit reached
    DAILY_LIMIT_EXCEEDED,      // Daily limit exceeded
    MONTHLY_LIMIT_APPROACHED,  // 80% of monthly limit
    MONTHLY_LIMIT_EXCEEDED,    // Monthly limit exceeded
    TRANSACTION_COUNT_HIGH,    // High transaction velocity
    SINGLE_TRANSACTION_LARGE,  // Single transaction exceeds normal patterns
    FRAUD_SCORE_ELEVATED,      // Sustained high fraud scores
    POSITION_CONCENTRATION     // Too much exposure to single merchant
}

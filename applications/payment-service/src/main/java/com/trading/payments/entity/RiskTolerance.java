package com.trading.payments.entity;

public enum RiskTolerance {
    LOW,      // Conservative limits
    MEDIUM,   // Standard limits
    HIGH,     // Aggressive limits
    UNLIMITED // No limits (admin override)
}

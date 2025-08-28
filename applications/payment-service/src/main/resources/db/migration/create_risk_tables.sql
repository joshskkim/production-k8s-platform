-- Merchant risk profiles table
CREATE TABLE IF NOT EXISTS merchant_risk_profiles (
    id SERIAL PRIMARY KEY,
    merchant_id VARCHAR(50) UNIQUE NOT NULL,
    daily_limit DECIMAL(12,2) DEFAULT 10000.00,
    monthly_limit DECIMAL(15,2) DEFAULT 250000.00,
    transaction_count_limit INTEGER DEFAULT 100,
    max_single_transaction DECIMAL(10,2) DEFAULT 5000.00,
    risk_tolerance VARCHAR(20) DEFAULT 'MEDIUM',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id)
);

-- Daily positions tracking table
CREATE TABLE IF NOT EXISTS daily_positions (
    id SERIAL PRIMARY KEY,
    merchant_id VARCHAR(50) NOT NULL,
    position_date DATE NOT NULL,
    total_volume DECIMAL(15,2) DEFAULT 0.00,
    transaction_count INTEGER DEFAULT 0,
    approved_volume DECIMAL(15,2) DEFAULT 0.00,
    approved_count INTEGER DEFAULT 0,
    declined_volume DECIMAL(15,2) DEFAULT 0.00,
    declined_count INTEGER DEFAULT 0,
    avg_fraud_score DECIMAL(5,2) DEFAULT 0.00,
    max_single_transaction DECIMAL(10,2) DEFAULT 0.00,
    risk_exposure_pct DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(merchant_id, position_date),
    FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id)
);

-- Risk alerts table
CREATE TABLE IF NOT EXISTS risk_alerts (
    id SERIAL PRIMARY KEY,
    merchant_id VARCHAR(50) NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    alert_level VARCHAR(20) NOT NULL,
    threshold_value DECIMAL(15,2),
    current_value DECIMAL(15,2),
    message TEXT,
    transaction_id VARCHAR(100),
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_positions_merchant_date ON daily_positions(merchant_id, position_date);
CREATE INDEX IF NOT EXISTS idx_daily_positions_date ON daily_positions(position_date);
CREATE INDEX IF NOT EXISTS idx_risk_alerts_merchant ON risk_alerts(merchant_id);
CREATE INDEX IF NOT EXISTS idx_risk_alerts_unresolved ON risk_alerts(is_resolved, created_at);
CREATE INDEX IF NOT EXISTS idx_risk_alerts_type_level ON risk_alerts(alert_type, alert_level);
#!/bin/bash
# Enhanced script to test fraud detection scenarios

API_URL="http://localhost:8080/api/v1/payments"

echo "🚀 Starting Enhanced Payment API Fraud Detection Test..."
echo "Testing endpoint: $API_URL"

# Test merchants
MERCHANTS=("MERCHANT_001" "MERCHANT_002" "MERCHANT_003" "MERCHANT_004" "MERCHANT_005")

# Test card numbers (fake, for demo)
CARDS=("4111111111111111" "4222222222222222" "4333333333333333" "4444444444444444")

# Function to send payment request
send_payment() {
    local merchant=$1
    local card=$2
    local amount=$3
    local description=$4
    
    echo "💳 $description"
    echo "   Merchant: $merchant | Card: ***${card: -4} | Amount: \$amount"
    
    response=$(curl -s -X POST "$API_URL/process" \
        -H "Content-Type: application/json" \
        -d "{
            \"merchantId\": \"$merchant\",
            \"cardNumber\": \"$card\",
            \"amount\": $amount,
            \"currency\": \"USD\",
            \"customerIp\": \"192.168.1.$(($RANDOM % 255))\",
            \"userAgent\": \"TestAgent/1.0\"
        }")
    
    # Extract key fields for display
    status=$(echo "$response" | jq -r '.status // "ERROR"')
    fraudScore=$(echo "$response" | jq -r '.fraudScore // "N/A"')
    reason=$(echo "$response" | jq -r '.message // "No message"')
    
    echo "   Result: $status (Score: $fraudScore)"
    echo "   Reason: $reason"
    echo ""
}

# Health check
echo "🏥 Health Check:"
curl -s "$API_URL/health" | jq '.'
echo ""

# Test Scenario 1: Normal transactions (should be approved)
echo "=== 📊 TEST SCENARIO 1: Normal Transactions ==="
send_payment "MERCHANT_001" "4111111111111111" "50.00" "Normal coffee purchase"
send_payment "MERCHANT_004" "4222222222222222" "25.75" "Restaurant meal"
send_payment "MERCHANT_002" "4333333333333333" "75.50" "Gas station"

# Test Scenario 2: High amount (should trigger fraud rule)
echo "=== 💰 TEST SCENARIO 2: High Amount Transactions ==="
send_payment "MERCHANT_001" "4111111111111111" "1500.00" "High amount purchase"
send_payment "MERCHANT_005" "4222222222222222" "2500.00" "Very high amount"

# Test Scenario 3: High-risk merchant (should add fraud score)
echo "=== ⚠️  TEST SCENARIO 3: High-Risk Merchant ==="
send_payment "MERCHANT_003" "4333333333333333" "500.00" "Crypto exchange transaction"
send_payment "MERCHANT_003" "4444444444444444" "800.00" "Another crypto transaction"

# Test Scenario 4: Suspicious round amounts
echo "=== 🎯 TEST SCENARIO 4: Suspicious Round Amounts ==="
send_payment "MERCHANT_001" "4111111111111111" "10000.00" "Exactly $10k (suspicious)"
send_payment "MERCHANT_002" "4222222222222222" "5000.00" "Exactly $5k"

# Test Scenario 5: Card velocity abuse (rapid transactions)
echo "=== 🏃 TEST SCENARIO 5: Card Velocity Abuse ==="
card_for_velocity="4111111111111111"
for i in {1..7}; do
    send_payment "MERCHANT_001" "$card_for_velocity" "100.00" "Rapid transaction #$i (velocity test)"
    sleep 0.2  # Small delay between requests
done

# Test Scenario 6: Amount pattern abuse
echo "=== 🔄 TEST SCENARIO 6: Amount Pattern Abuse ==="
pattern_card="4222222222222222"
for i in {1..4}; do
    send_payment "MERCHANT_004" "$pattern_card" "99.99" "Repeated amount #$i (pattern test)"
    sleep 0.1
done

# Test Scenario 7: Merchant velocity
echo "=== 🏪 TEST SCENARIO 7: Merchant Velocity Test ==="
for i in {1..10}; do
    card=${CARDS[$((RANDOM % ${#CARDS[@]}))]}
    send_payment "MERCHANT_002" "$card" "$(($RANDOM % 100 + 10)).00" "Merchant velocity test #$i"
    sleep 0.1
done

echo "📊 Final Merchant Summaries:"
for merchant in "${MERCHANTS[@]}"; do
    echo "--- $merchant ---"
    curl -s "$API_URL/merchant/$merchant/summary?hours=1" | jq '.'
    echo ""
done

echo "✅ Fraud detection test complete!"
echo ""
echo "🔍 Check Redis cache:"
echo "docker-compose exec redis redis-cli keys '*'"
echo ""
echo "🔍 Check database:"
echo "docker-compose exec postgres psql -U postgres -d trading_platform -c 'SELECT status, COUNT(*), AVG(fraud_score) FROM transactions GROUP BY status;'"
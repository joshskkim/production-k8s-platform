#!/bin/bash
# Script to generate test payment transactions

API_URL="http://localhost:8080/api/v1/payments"

echo "🚀 Starting Payment API Load Test..."
echo "Testing endpoint: $API_URL"

# Test merchants
MERCHANTS=("MERCHANT_001" "MERCHANT_002" "MERCHANT_003" "MERCHANT_004" "MERCHANT_005")

# Test card numbers (fake, for demo)
CARDS=("4111111111111111" "4222222222222222" "4333333333333333" "4444444444444444")

# Function to generate random amount
random_amount() {
    echo "scale=2; $(($RANDOM % 2000 + 10))/100" | bc
}

# Function to send payment request
send_payment() {
    local merchant=$1
    local card=$2
    local amount=$3
    
    curl -s -X POST "$API_URL/process" \
        -H "Content-Type: application/json" \
        -d "{
            \"merchantId\": \"$merchant\",
            \"cardNumber\": \"$card\",
            \"amount\": $amount,
            \"currency\": \"USD\",
            \"customerIp\": \"192.168.1.$(($RANDOM % 255))\",
            \"userAgent\": \"TestAgent/1.0\"
        }" | jq '.'
}

# Check health first
echo "🏥 Health Check:"
curl -s "$API_URL/health" | jq '.'
echo ""

# Generate test transactions
echo "💳 Generating test transactions..."
for i in {1..20}; do
    merchant=${MERCHANTS[$((RANDOM % ${#MERCHANTS[@]}))]}
    card=${CARDS[$((RANDOM % ${#CARDS[@]}))]}
    amount=$(random_amount)
    
    echo "Transaction $i: $merchant - \$$amount"
    send_payment "$merchant" "$card" "$amount"
    echo "---"
    
    # Small delay to avoid overwhelming the system
    sleep 0.5
done

# Test high-risk transaction (should be declined)
echo "🚨 Testing high-risk transaction..."
send_payment "MERCHANT_003" "4111111111111111" "10000.00"

echo ""
echo "📊 Merchant Summary for MERCHANT_001:"
curl -s "$API_URL/merchant/MERCHANT_001/summary" | jq '.'

echo ""
echo "✅ Load test complete!"
echo "Check logs with: docker-compose logs payment-service"
// K6 load test script for payment processing platform

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');

// Test configuration
export let options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp up to 20 users
    { duration: '1m', target: 50 },   // Stay at 50 users
    { duration: '30s', target: 100 }, // Ramp up to 100 users
    { duration: '2m', target: 100 },  // Stay at 100 users
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.05'],   // Error rate must be below 5%
    errors: ['rate<0.1'],             // Custom error rate below 10%
  },
};

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8080';

// Test data
const merchants = ['MERCHANT_001', 'MERCHANT_002', 'MERCHANT_003', 'MERCHANT_004', 'MERCHANT_005'];
const cards = ['4111111111111111', '4222222222222222', '4333333333333333', '4444444444444444'];

function getRandomAmount() {
  return Math.floor(Math.random() * 1000) + 10; // $10 - $1010
}

function getRandomElement(array) {
  return array[Math.floor(Math.random() * array.length)];
}

export default function () {
  // Test 1: Health check
  let healthResponse = http.get(`${BASE_URL}/api/v1/payments/health`);
  check(healthResponse, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 100ms': (r) => r.timings.duration < 100,
  }) || errorRate.add(1);

  // Test 2: Process payment
  let paymentPayload = {
    merchantId: getRandomElement(merchants),
    cardNumber: getRandomElement(cards),
    amount: getRandomAmount(),
    currency: 'USD',
    customerIp: `192.168.1.${Math.floor(Math.random() * 255)}`,
    userAgent: 'LoadTest/1.0'
  };

  let paymentResponse = http.post(
    `${BASE_URL}/api/v1/payments/process`,
    JSON.stringify(paymentPayload),
    {
      headers: {
        'Content-Type': 'application/json',
      },
    }
  );

  let paymentChecks = check(paymentResponse, {
    'payment status is 200': (r) => r.status === 200,
    'payment response time < 500ms': (r) => r.timings.duration < 500,
    'payment has transaction ID': (r) => JSON.parse(r.body).transactionId !== undefined,
    'payment processed successfully': (r) => {
      const body = JSON.parse(r.body);
      return body.status === 'APPROVED' || body.status === 'DECLINED' || body.status === 'BLOCKED';
    },
  });

  if (!paymentChecks) {
    errorRate.add(1);
    console.error(`Payment failed: ${paymentResponse.status} ${paymentResponse.body}`);
  }

  // Test 3: Get transaction status (if payment succeeded)
  if (paymentResponse.status === 200) {
    const paymentBody = JSON.parse(paymentResponse.body);
    if (paymentBody.transactionId) {
      let statusResponse = http.get(`${BASE_URL}/api/v1/payments/status/${paymentBody.transactionId}`);
      check(statusResponse, {
        'status check returns 200 or 404': (r) => r.status === 200 || r.status === 404,
        'status response time < 200ms': (r) => r.timings.duration < 200,
      }) || errorRate.add(1);
    }
  }

  // Test 4: Get merchant summary (every 10th iteration)
  if (__ITER % 10 === 0) {
    let merchantId = getRandomElement(merchants);
    let summaryResponse = http.get(`${BASE_URL}/api/v1/payments/merchant/${merchantId}/summary`);
    check(summaryResponse, {
      'merchant summary status is 200': (r) => r.status === 200,
      'merchant summary response time < 300ms': (r) => r.timings.duration < 300,
    }) || errorRate.add(1);
  }

  // Test 5: Risk management endpoints (every 20th iteration)
  if (__ITER % 20 === 0) {
    // Portfolio summary
    let portfolioResponse = http.get(`${BASE_URL}/api/v1/payments/risk/portfolio/summary`);
    check(portfolioResponse, {
      'portfolio summary status is 200': (r) => r.status === 200,
      'portfolio response time < 200ms': (r) => r.timings.duration < 200,
    }) || errorRate.add(1);

    // Risk alerts
    let alertsResponse = http.get(`${BASE_URL}/api/v1/payments/risk/alerts`);
    check(alertsResponse, {
      'risk alerts status is 200': (r) => r.status === 200,
      'alerts response time < 300ms': (r) => r.timings.duration < 300,
    }) || errorRate.add(1);
  }

  // Simulate realistic user behavior
  sleep(Math.random() * 2 + 0.5); // 0.5 to 2.5 seconds between requests
}

export function handleSummary(data) {
  return {
    'load-test-results.json': JSON.stringify(data, null, 2),
    stdout: `
    ========================================
    PAYMENT PLATFORM LOAD TEST RESULTS
    ========================================
    
    Total Requests: ${data.metrics.http_reqs.values.count}
    Failed Requests: ${data.metrics.http_req_failed.values.rate * 100}%
    Average Response Time: ${data.metrics.http_req_duration.values.avg}ms
    95th Percentile Response Time: ${data.metrics.http_req_duration.values['p(95)']}ms
    
    Throughput: ${data.metrics.http_reqs.values.rate}/sec
    Error Rate: ${data.metrics.errors ? data.metrics.errors.values.rate * 100 : 0}%
    
    Payment Processing Performance:
    - Sub-500ms: ${data.metrics.http_req_duration.values['p(95)'] < 500 ? '✅ PASS' : '❌ FAIL'}
    - Error Rate < 5%: ${data.metrics.http_req_failed.values.rate < 0.05 ? '✅ PASS' : '❌ FAIL'}
    
    ========================================
    `
  };
}
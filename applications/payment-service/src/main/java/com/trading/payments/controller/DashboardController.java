package com.trading.payments.controller;

import com.trading.payments.service.PaymentEventService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.messaging.simp.annotation.SubscribeMapping;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.time.Instant;
import java.util.Map;

@Controller
@RequiredArgsConstructor
@Slf4j
public class DashboardController {
    
    private final PaymentEventService eventService;
    
    /**
     * WebSocket endpoint for client subscriptions
     */
    @SubscribeMapping("/topic/transactions")
    public void subscribeToTransactions() {
        log.info("Client subscribed to transaction feed");
    }
    
    @SubscribeMapping("/topic/fraud-alerts") 
    public void subscribeToFraudAlerts() {
        log.info("Client subscribed to fraud alerts");
    }
    
    @SubscribeMapping("/topic/dashboard/stats")
    public void subscribeToDashboardStats() {
        log.info("Client subscribed to dashboard stats");
        // Immediately send current stats to new subscriber
        eventService.broadcastDashboardStats();
    }
    
    /**
     * Handle dashboard commands from clients
     */
    @MessageMapping("/dashboard/refresh")
    @SendTo("/topic/dashboard/stats")
    public void refreshDashboard() {
        log.info("Dashboard refresh requested");
        eventService.broadcastDashboardStats();
    }
    
    /**
     * REST endpoint for WebSocket testing page
     */
    @GetMapping("/dashboard")
    @ResponseBody
    public String getDashboardPage() {
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Payment Processing Dashboard</title>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/sockjs-client/1.6.1/sockjs.min.js"></script>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/stomp.js/2.3.3/stomp.min.js"></script>
                <style>
                    body { font-family: Arial, sans-serif; margin: 20px; background: #1a1a1a; color: #fff; }
                    .container { max-width: 1200px; margin: 0 auto; }
                    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
                    .stat-card { background: #2d2d2d; padding: 20px; border-radius: 8px; border: 1px solid #444; }
                    .stat-value { font-size: 2em; font-weight: bold; color: #4CAF50; }
                    .stat-label { color: #ccc; margin-top: 5px; }
                    .events { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
                    .event-feed { background: #2d2d2d; padding: 20px; border-radius: 8px; border: 1px solid #444; height: 400px; overflow-y: auto; }
                    .transaction { padding: 10px; border-bottom: 1px solid #444; margin-bottom: 5px; }
                    .approved { border-left: 3px solid #4CAF50; }
                    .declined { border-left: 3px solid #f44336; }
                    .fraud-alert { border-left: 3px solid #ff9800; background: #3d2914; }
                    .connection-status { margin-bottom: 20px; padding: 10px; border-radius: 4px; }
                    .connected { background: #1b5e20; }
                    .disconnected { background: #b71c1c; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🚀 Payment Processing Dashboard</h1>
                    
                    <div id="connectionStatus" class="connection-status disconnected">
                        📡 Connecting to WebSocket...
                    </div>
                    
                    <div class="stats">
                        <div class="stat-card">
                            <div class="stat-value" id="totalTransactions">0</div>
                            <div class="stat-label">Total Transactions</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value" id="fraudAlerts">0</div>
                            <div class="stat-label">Fraud Alerts</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value" id="approvalRate">0%</div>
                            <div class="stat-label">Approval Rate</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value" id="avgFraudScore">0</div>
                            <div class="stat-label">Avg Fraud Score</div>
                        </div>
                    </div>
                    
                    <div class="events">
                        <div>
                            <h3>📊 Live Transaction Feed</h3>
                            <div id="transactionFeed" class="event-feed"></div>
                        </div>
                        <div>
                            <h3>🚨 Fraud Alerts</h3>
                            <div id="fraudFeed" class="event-feed"></div>
                        </div>
                    </div>
                </div>
                
                <script>
                    let stompClient = null;
                    let stats = { total: 0, fraud: 0, approved: 0 };
                    
                    function connect() {
                        const socket = new SockJS('/ws/payments');
                        stompClient = Stomp.over(socket);
                        
                        stompClient.connect({}, function(frame) {
                            console.log('Connected: ' + frame);
                            document.getElementById('connectionStatus').innerHTML = '✅ Connected to Payment Stream';
                            document.getElementById('connectionStatus').className = 'connection-status connected';
                            
                            // Subscribe to transaction events
                            stompClient.subscribe('/topic/transactions', function(event) {
                                const transaction = JSON.parse(event.body);
                                displayTransaction(transaction);
                                updateStats(transaction);
                            });
                            
                            // Subscribe to fraud alerts
                            stompClient.subscribe('/topic/fraud-alerts', function(alert) {
                                const fraudAlert = JSON.parse(alert.body);
                                displayFraudAlert(fraudAlert);
                            });
                            
                            // Subscribe to dashboard stats
                            stompClient.subscribe('/topic/dashboard/stats', function(statsUpdate) {
                                const newStats = JSON.parse(statsUpdate.body);
                                updateDashboardStats(newStats);
                            });
                            
                        }, function(error) {
                            console.error('WebSocket connection error:', error);
                            document.getElementById('connectionStatus').innerHTML = '❌ Connection Failed';
                            document.getElementById('connectionStatus').className = 'connection-status disconnected';
                            setTimeout(connect, 5000); // Retry connection
                        });
                    }
                    
                    function displayTransaction(transaction) {
                        const feed = document.getElementById('transactionFeed');
                        const div = document.createElement('div');
                        div.className = 'transaction ' + transaction.status.toLowerCase();
                        div.innerHTML = `
                            <strong>${transaction.transactionId}</strong><br>
                            ${transaction.merchantId} - $${transaction.amount}<br>
                            <span style="color: ${transaction.status === 'APPROVED' ? '#4CAF50' : '#f44336'}">
                                ${transaction.status} (Score: ${transaction.fraudScore})
                            </span>
                            <span style="float: right; font-size: 0.8em; color: #999;">
                                ${new Date(transaction.timestamp).toLocaleTimeString()}
                            </span>
                        `;
                        feed.insertBefore(div, feed.firstChild);
                        if (feed.children.length > 50) feed.removeChild(feed.lastChild);
                    }
                    
                    function displayFraudAlert(alert) {
                        const feed = document.getElementById('fraudFeed');
                        const div = document.createElement('div');
                        div.className = 'transaction fraud-alert';
                        div.innerHTML = `
                            <strong>🚨 ${alert.transactionId}</strong><br>
                            ${alert.merchantId} - $${alert.amount}<br>
                            <span style="color: #ff9800;">Risk: ${alert.riskLevel} (${alert.fraudScore})</span><br>
                            <small>${alert.message}</small>
                            <span style="float: right; font-size: 0.8em; color: #999;">
                                ${new Date(alert.timestamp).toLocaleTimeString()}
                            </span>
                        `;
                        feed.insertBefore(div, feed.firstChild);
                        if (feed.children.length > 30) feed.removeChild(feed.lastChild);
                    }
                    
                    function updateStats(transaction) {
                        stats.total++;
                        if (transaction.status === 'APPROVED') stats.approved++;
                        if (transaction.fraudScore > 50) stats.fraud++;
                        
                        document.getElementById('totalTransactions').textContent = stats.total;
                        document.getElementById('fraudAlerts').textContent = stats.fraud;
                        document.getElementById('approvalRate').textContent = 
                            stats.total > 0 ? Math.round(stats.approved / stats.total * 100) + '%' : '0%';
                    }
                    
                    function updateDashboardStats(newStats) {
                        if (newStats.totalTransactions) {
                            document.getElementById('totalTransactions').textContent = newStats.totalTransactions;
                        }
                        if (newStats.fraudAlerts) {
                            document.getElementById('fraudAlerts').textContent = newStats.fraudAlerts;
                        }
                    }
                    
                    // Connect on page load
                    connect();
                </script>
            </body>
            </html>
            """;
    }
}

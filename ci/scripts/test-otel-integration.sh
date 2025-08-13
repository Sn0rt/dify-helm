#!/bin/bash
set -e

echo "🚀 Starting OpenTelemetry integration tests..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for condition with timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-300}"
    local interval="${3:-5}"
    local elapsed=0
    
    echo "⏳ Waiting for condition: $condition (timeout: ${timeout}s)"
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition"; then
            echo "✅ Condition met after ${elapsed}s"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo "⏳ Still waiting... (${elapsed}s/${timeout}s)"
    done
    
    echo "❌ Timeout: condition not met after ${timeout}s"
    return 1
}

# Function to check pod logs for specific patterns
check_logs_for_pattern() {
    local deployment="$1"
    local pattern="$2"
    local timeout="${3:-60}"
    
    echo "🔍 Checking logs of $deployment for pattern: $pattern"
    
    # Get pods for deployment
    local pods=$(kubectl get pods -l app.kubernetes.io/name=${deployment#deployment/} -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        echo "❌ No pods found for deployment $deployment"
        return 1
    fi
    
    for pod in $pods; do
        echo "📋 Checking logs of pod: $pod"
        if kubectl logs "$pod" --tail=100 | grep -E "$pattern" >/dev/null 2>&1; then
            echo "✅ Found pattern in pod $pod logs"
            return 0
        fi
    done
    
    echo "❌ Pattern not found in any pod logs"
    return 1
}

# 1. Verify OpenTelemetry Collector is running
echo "📊 Step 1: Verify OpenTelemetry Collector is running"
if ! kubectl get deployment otel-collector-opentelemetry-collector >/dev/null 2>&1; then
    echo "❌ OpenTelemetry Collector deployment not found!"
    exit 1
fi

if ! kubectl wait --for=condition=available deployment/otel-collector-opentelemetry-collector --timeout=300s; then
    echo "❌ OpenTelemetry Collector not ready!"
    kubectl describe deployment otel-collector-opentelemetry-collector
    kubectl logs deployment/otel-collector-opentelemetry-collector --tail=50 || true
    exit 1
fi

echo "✅ OpenTelemetry Collector is running"

# 2. Check OpenTelemetry Collector service
echo "🌐 Step 2: Verify OpenTelemetry Collector service"
collector_service="otel-collector-opentelemetry-collector"
if ! kubectl get service "$collector_service" >/dev/null 2>&1; then
    echo "❌ OpenTelemetry Collector service not found!"
    exit 1
fi

# Get service endpoints
kubectl get endpoints "$collector_service" -o yaml | grep -E "addresses|ports" || true
echo "✅ OpenTelemetry Collector service is available"

# 3. Verify Dify components are running
echo "🚀 Step 3: Verify Dify components are running"
for component in api worker; do
    echo "⏳ Checking dify-$component..."
    if ! kubectl wait --for=condition=available deployment/dify-$component --timeout=300s; then
        echo "❌ dify-$component not ready!"
        kubectl describe deployment dify-$component
        kubectl logs deployment/dify-$component --tail=50 || true
        exit 1
    fi
    echo "✅ dify-$component is running"
done

# 4. Verify OTEL environment variables are set
echo "🔧 Step 4: Verify OTEL environment variables in Dify components"
for component in api worker; do
    echo "🔍 Checking OTEL environment variables in dify-$component..."
    
    # Check if ENABLE_OTEL is set to true
    if ! kubectl exec deployment/dify-$component -- env | grep "ENABLE_OTEL=true" >/dev/null 2>&1; then
        echo "❌ ENABLE_OTEL not set to true in dify-$component"
        echo "Current environment variables:"
        kubectl exec deployment/dify-$component -- env | grep -E "(OTEL|otel)" || echo "No OTEL variables found"
        exit 1
    fi
    
    # Check OTLP_BASE_ENDPOINT
    if ! kubectl exec deployment/dify-$component -- env | grep "OTLP_BASE_ENDPOINT.*otel-collector" >/dev/null 2>&1; then
        echo "❌ OTLP_BASE_ENDPOINT not properly configured in dify-$component"
        kubectl exec deployment/dify-$component -- env | grep -E "OTLP.*ENDPOINT" || echo "No OTLP endpoints found"
        exit 1
    fi
    
    echo "✅ OTEL environment variables correctly set in dify-$component"
done

# 5. Check initial OpenTelemetry Collector logs
echo "📋 Step 5: Check initial OpenTelemetry Collector logs"
echo "🔍 Current OpenTelemetry Collector logs:"
kubectl logs deployment/otel-collector-opentelemetry-collector --tail=20 || true

# 6. Trigger application activity to generate telemetry data
echo "🎯 Step 6: Trigger application activity to generate telemetry data"

# Port forward to access Dify API
echo "🌐 Setting up port forwarding to Dify proxy..."
kubectl port-forward service/dify-proxy 8080:80 &
port_forward_pid=$!

# Wait for port forward to be ready
sleep 5

# Function to cleanup port forward
cleanup() {
    echo "🧹 Cleaning up port forwarding..."
    kill $port_forward_pid 2>/dev/null || true
    wait $port_forward_pid 2>/dev/null || true
}
trap cleanup EXIT

# Test basic connectivity
echo "🏥 Testing basic health check..."
if curl -s -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "✅ Health check successful"
else
    echo "⚠️  Health check failed, but continuing..."
fi

# Make several API requests to generate telemetry data
echo "🔄 Making API requests to generate telemetry data..."
for i in {1..5}; do
    echo "📤 Request $i/5..."
    curl -s -f http://localhost:8080/health || echo "Request $i failed"
    sleep 2
done

# Wait for telemetry data to be processed
echo "⏳ Waiting for telemetry data to be processed..."
sleep 15

# 7. Verify telemetry data in OpenTelemetry Collector
echo "📊 Step 7: Verify telemetry data in OpenTelemetry Collector"

echo "🔍 Checking OpenTelemetry Collector logs for telemetry data..."
collector_logs=$(kubectl logs deployment/otel-collector-opentelemetry-collector --tail=100)

# Check for traces
if echo "$collector_logs" | grep -E "(trace|span|Span)" >/dev/null 2>&1; then
    echo "✅ Found trace data in OpenTelemetry Collector logs"
    trace_found=true
else
    echo "⚠️  No trace data found in OpenTelemetry Collector logs"
    trace_found=false
fi

# Check for metrics
if echo "$collector_logs" | grep -E "(metric|Metric|datapoint)" >/dev/null 2>&1; then
    echo "✅ Found metric data in OpenTelemetry Collector logs"
    metric_found=true
else
    echo "⚠️  No metric data found in OpenTelemetry Collector logs"
    metric_found=false
fi

# Check for OTLP receiver activity
if echo "$collector_logs" | grep -E "(otlp|OTLP|otlpreceiver)" >/dev/null 2>&1; then
    echo "✅ Found OTLP receiver activity in OpenTelemetry Collector logs"
    otlp_found=true
else
    echo "⚠️  No OTLP receiver activity found in OpenTelemetry Collector logs"
    otlp_found=false
fi

# 8. Check for telemetry file output
echo "📁 Step 8: Check for telemetry file output"
if kubectl exec deployment/otel-collector-opentelemetry-collector -- ls -la /tmp/otel-data.json >/dev/null 2>&1; then
    echo "✅ Telemetry data file exists"
    file_size=$(kubectl exec deployment/otel-collector-opentelemetry-collector -- stat -c%s /tmp/otel-data.json 2>/dev/null || echo "0")
    if [ "$file_size" -gt 0 ]; then
        echo "✅ Telemetry data file has content (${file_size} bytes)"
        file_found=true
    else
        echo "⚠️  Telemetry data file is empty"
        file_found=false
    fi
else
    echo "⚠️  Telemetry data file not found"
    file_found=false
fi

# 9. Check Dify application logs for OTEL-related output
echo "🔍 Step 9: Check Dify application logs for OTEL-related output"
for component in api worker; do
    echo "📋 Checking dify-$component logs for OTEL activity..."
    if kubectl logs deployment/dify-$component --tail=50 | grep -E -i "(otel|opentelemetry|telemetry|trace|span)" >/dev/null 2>&1; then
        echo "✅ Found OTEL-related activity in dify-$component logs"
    else
        echo "⚠️  No obvious OTEL activity in dify-$component logs"
    fi
done

# 10. Final assessment
echo "📈 Step 10: Final assessment"
echo "================== RESULTS =================="
echo "Trace data found: $trace_found"
echo "Metric data found: $metric_found"
echo "OTLP receiver activity: $otlp_found"
echo "Telemetry file created: $file_found"
echo "=============================================="

# Determine overall success
success_count=0
if [ "$trace_found" = true ]; then ((success_count++)); fi
if [ "$metric_found" = true ]; then ((success_count++)); fi
if [ "$otlp_found" = true ]; then ((success_count++)); fi
if [ "$file_found" = true ]; then ((success_count++)); fi

echo "📊 Success indicators: $success_count/4"

if [ $success_count -ge 2 ]; then
    echo "🎉 OpenTelemetry integration test PASSED!"
    echo "✅ Sufficient evidence of working OTEL integration found"
    
    # Show some sample telemetry data
    echo "📋 Sample OpenTelemetry Collector logs:"
    echo "$collector_logs" | tail -20
    
    exit 0
else
    echo "❌ OpenTelemetry integration test FAILED!"
    echo "❌ Insufficient evidence of working OTEL integration"
    
    echo "🔍 Debugging information:"
    echo "--- OpenTelemetry Collector logs ---"
    echo "$collector_logs"
    
    echo "--- OpenTelemetry Collector status ---"
    kubectl describe deployment otel-collector-opentelemetry-collector
    
    echo "--- OpenTelemetry Collector endpoints ---"
    kubectl get endpoints otel-collector-opentelemetry-collector -o yaml
    
    echo "--- Dify API logs (last 30 lines) ---"
    kubectl logs deployment/dify-api --tail=30 || true
    
    echo "--- Dify Worker logs (last 30 lines) ---"
    kubectl logs deployment/dify-worker --tail=30 || true
    
    exit 1
fi
#!/bin/bash

# Test script for Claude CLI integration
echo "=== Testing Claude CLI Integration ==="

# Test 1: Check if claude command exists
echo "1. Checking if claude command is available..."
if command -v claude &> /dev/null; then
    echo "✅ Claude CLI found at: $(which claude)"
    echo "   Version: $(claude --version)"
else
    echo "❌ Claude CLI not found"
    exit 1
fi

# Test 2: Test basic functionality
echo ""
echo "2. Testing basic Claude CLI functionality..."
echo "Hello, can you respond with just 'OK'?" | claude --print > /tmp/claude_test.txt 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Claude CLI basic test passed"
    echo "   Response: $(cat /tmp/claude_test.txt)"
else
    echo "❌ Claude CLI basic test failed"
    echo "   Error output:"
    cat /tmp/claude_test.txt
    exit 1
fi

# Test 3: Test with model specification
echo ""
echo "3. Testing with model specification..."
echo "Say 'Test successful' in French" | claude --print --model sonnet > /tmp/claude_model_test.txt 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Claude CLI model test passed"
    echo "   Response: $(cat /tmp/claude_model_test.txt)"
else
    echo "❌ Claude CLI model test failed"
    echo "   Error output:"
    cat /tmp/claude_model_test.txt
fi

# Clean up
rm -f /tmp/claude_test.txt /tmp/claude_model_test.txt

echo ""
echo "=== Claude CLI Testing Complete ==="
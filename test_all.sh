#!/bin/bash

echo "🚀 Real-time comparison: ccusage vs Swift CLI vs Swift MenuBar"
echo "============================================================="

# Run all three simultaneously to avoid timing differences
echo "📊 Running ccusage..."
CCUSAGE_RESULT=$(npx ccusage@latest daily --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for entry in data.get('daily', []):
    if entry.get('date') == '2025-06-09':
        print(entry['totalTokens'])
        break
")

echo "📊 Running Swift CLI..."
SWIFT_CLI_RESULT=$(swift swift-cli/simple_output.swift | grep "Total:" | awk '{print $2}')

echo "📊 Running Swift MenuBar logic..."
MENUBAR_RESULT=$(cd swift-test && swift debug_menubar.swift | grep "   Total:" | awk '{print $2}')

echo ""
echo "🎯 SIDE-BY-SIDE COMPARISON (2025-06-09):"
echo "========================================="
printf "%-15s %-15s %-15s %-15s\n" "Tool" "Total Tokens" "Diff from ccusage" "Match?"
printf "%-15s %-15s %-15s %-15s\n" "----" "------------" "----------------" "------"
printf "%-15s %-15s %-15s %-15s\n" "ccusage" "$CCUSAGE_RESULT" "0" "✅"

if [ -n "$SWIFT_CLI_RESULT" ]; then
    CLI_DIFF=$((SWIFT_CLI_RESULT - CCUSAGE_RESULT))
    CLI_MATCH="❌"
    if [ "$CLI_DIFF" -eq 0 ]; then
        CLI_MATCH="✅"
    fi
    printf "%-15s %-15s %-15s %-15s\n" "Swift CLI" "$SWIFT_CLI_RESULT" "$CLI_DIFF" "$CLI_MATCH"
fi

if [ -n "$MENUBAR_RESULT" ]; then
    MENUBAR_DIFF=$((MENUBAR_RESULT - CCUSAGE_RESULT))
    MENUBAR_MATCH="❌"
    if [ "$MENUBAR_DIFF" -eq 0 ]; then
        MENUBAR_MATCH="✅"
    fi
    printf "%-15s %-15s %-15s %-15s\n" "Swift MenuBar" "$MENUBAR_RESULT" "$MENUBAR_DIFF" "$MENUBAR_MATCH"
fi

echo ""
if [ "$SWIFT_CLI_RESULT" -eq "$CCUSAGE_RESULT" ] && [ "$MENUBAR_RESULT" -eq "$CCUSAGE_RESULT" ]; then
    echo "🎉 PERFECT MATCH! All tools show identical results."
elif [ "$SWIFT_CLI_RESULT" -eq "$CCUSAGE_RESULT" ]; then
    echo "✅ Swift CLI matches ccusage perfectly"
    echo "⚠️  Swift MenuBar needs debugging"
else
    echo "⚠️  There are calculation differences to investigate"
fi
#!/bin/bash

echo "🎯 Final Check - ccusage vs ccusage-menubar"
echo "==========================================="
echo

# Get ccusage values
echo "📊 Expected values from ccusage CLI:"
echo

# Use JSON for precise values
daily_auto=$(ccusage daily --mode auto --json 2>/dev/null | jq -r '.daily[] | select(.date == "2025-06-19") | .totalCost')
daily_calc=$(ccusage daily --mode calculate --json 2>/dev/null | jq -r '.daily[] | select(.date == "2025-06-19") | .totalCost')
daily_display=$(ccusage daily --mode display --json 2>/dev/null | jq -r '.daily[] | select(.date == "2025-06-19") | .totalCost')

monthly_auto=$(ccusage monthly --mode auto --json 2>/dev/null | jq -r '.totals.totalCost')
monthly_calc=$(ccusage monthly --mode calculate --json 2>/dev/null | jq -r '.totals.totalCost')
monthly_display=$(ccusage monthly --mode display --json 2>/dev/null | jq -r '.totals.totalCost')

# Format to 2 decimals
printf "Today (2025-06-19):\n"
printf "  Auto:      $%.2f\n" $daily_auto
printf "  Calculate: $%.2f\n" $daily_calc
printf "  Display:   $%.2f\n" $daily_display
printf "\n"
printf "This Month:\n"
printf "  Auto:      $%.2f\n" $monthly_auto
printf "  Calculate: $%.2f\n" $monthly_calc
printf "  Display:   $%.2f\n" $monthly_display

echo
echo "✅ The menu bar app should show EXACTLY these values!"
echo
echo "⚠️  Important: If using cached data, values will be wrong!"
echo "   Clear cache with: rm -rf ~/.claude_ultra_cache/"
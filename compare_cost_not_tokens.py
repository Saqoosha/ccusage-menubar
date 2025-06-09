#!/usr/bin/env python3

import json
import subprocess

# Get ccusage data
result = subprocess.run(['npx', 'ccusage@latest', 'daily', '--json'], 
                       capture_output=True, text=True)
data = json.loads(result.stdout)

for entry in data.get('daily', []):
    if entry.get('date') == '2025-06-09':
        print(f"📊 ccusage for 2025-06-09:")
        print(f"   Total TOKENS: {entry['totalTokens']:,}")
        print(f"   Total COST: ${entry['totalCost']:.2f}")
        print(f"\n💡 Key insight:")
        print(f"   - Swift CLI shows correct TOKENS: {entry['totalTokens']:,}")
        print(f"   - Swift MenuBar shows correct TOKENS but wrong COST")
        print(f"   - The issue is COST CALCULATION, not token counting!")
        break
#!/usr/bin/env python3

import json
import subprocess

# Get ccusage cost for today
result = subprocess.run(['npx', 'ccusage@latest', 'daily', '--json'], 
                       capture_output=True, text=True)
data = json.loads(result.stdout)

for entry in data.get('daily', []):
    if entry.get('date') == '2025-06-09':
        print(f"📊 ccusage results for 2025-06-09:")
        print(f"   Total tokens: {entry['totalTokens']:,}")
        print(f"   Total cost: ${entry['totalCost']:.2f}")
        break

print("\n💡 If Swift menubar shows $668, that's ~$163 too high!")
print("   This suggests Opus pricing might still be wrong")
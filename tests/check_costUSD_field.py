#!/usr/bin/env python3

import json
import os
from pathlib import Path

claude_path = Path.home() / ".claude" / "projects"
has_cost = 0
no_cost = 0
total_cost_from_field = 0.0

# Check actual JSONL entries for 2025-06-09
for jsonl_file in claude_path.rglob("*.jsonl"):
    try:
        with open(jsonl_file, 'r') as f:
            for line in f:
                if line.strip():
                    data = json.loads(line)
                    timestamp = data.get('timestamp', '')
                    
                    if timestamp.startswith('2025-06-09'):
                        if 'costUSD' in data:
                            has_cost += 1
                            total_cost_from_field += data['costUSD']
                            if has_cost <= 3:  # Show first few examples
                                print(f"✅ Entry WITH costUSD: ${data['costUSD']:.6f}")
                                if 'message' in data and 'model' in data['message']:
                                    print(f"   Model: {data['message']['model']}")
                        else:
                            no_cost += 1
                            if no_cost <= 3:  # Show first few examples
                                print(f"❌ Entry WITHOUT costUSD")
                                if 'message' in data and 'model' in data['message']:
                                    print(f"   Model: {data['message']['model']}")
    except:
        continue

print(f"\n📊 Summary for 2025-06-09:")
print(f"Entries WITH costUSD: {has_cost}")
print(f"Entries WITHOUT costUSD: {no_cost}")
print(f"Total cost from costUSD fields: ${total_cost_from_field:.2f}")
print(f"\n💡 ccusage shows: $533.39")
print(f"Difference: ${533.39 - total_cost_from_field:.2f}")
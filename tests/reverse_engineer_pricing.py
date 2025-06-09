#!/usr/bin/env python3

import json
import subprocess

# Get token counts for today
result = subprocess.run(['npx', 'ccusage@latest', 'daily', '--json'], 
                       capture_output=True, text=True)
data = json.loads(result.stdout)

for entry in data.get('daily', []):
    if entry.get('date') == '2025-06-09':
        input_tokens = entry['inputTokens']
        output_tokens = entry['outputTokens']
        cache_create = entry['cacheCreationTokens']
        cache_read = entry['cacheReadTokens']
        total_cost = entry['totalCost']
        
        print(f"📊 ccusage data for 2025-06-09:")
        print(f"   Input: {input_tokens:,}")
        print(f"   Output: {output_tokens:,}")
        print(f"   Cache Create: {cache_create:,}")
        print(f"   Cache Read: {cache_read:,}")
        print(f"   Total Cost: ${total_cost:.2f}")
        
        # Try different pricing combinations
        print(f"\n🔍 Testing pricing scenarios:")
        
        # Scenario 1: All models use Sonnet pricing
        sonnet_input = 3e-06
        sonnet_output = 1.5e-05
        cache_rate = 0.00000249
        
        cost1 = (input_tokens * sonnet_input + 
                output_tokens * sonnet_output + 
                cache_create * cache_rate + 
                cache_read * cache_rate)
        
        print(f"\n1. All models at Sonnet rates:")
        print(f"   Calculated: ${cost1:.2f}")
        print(f"   Difference: ${abs(cost1 - total_cost):.2f}")
        
        # Scenario 2: Try different cache rates
        cache_rate2 = 3.75e-06  # Higher cache rate
        cost2 = (input_tokens * sonnet_input + 
                output_tokens * sonnet_output + 
                cache_create * cache_rate2 + 
                cache_read * cache_rate2)
        
        print(f"\n2. Sonnet rates with higher cache ($3.75/M):")
        print(f"   Calculated: ${cost2:.2f}")
        print(f"   Difference: ${abs(cost2 - total_cost):.2f}")
        
        break
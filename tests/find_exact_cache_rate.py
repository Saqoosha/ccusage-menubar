#!/usr/bin/env python3

import json
import subprocess

# Get token counts
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
        
        # Known rates
        input_rate = 3e-06
        output_rate = 1.5e-05
        
        # Calculate non-cache cost
        non_cache_cost = input_tokens * input_rate + output_tokens * output_rate
        
        # What's left must be cache cost
        cache_cost = total_cost - non_cache_cost
        total_cache_tokens = cache_create + cache_read
        
        # Calculate effective cache rate
        if total_cache_tokens > 0:
            effective_cache_rate = cache_cost / total_cache_tokens
            
            print(f"🔍 Reverse Engineering Cache Rate:")
            print(f"   Total cost: ${total_cost:.2f}")
            print(f"   Non-cache cost: ${non_cache_cost:.2f}")
            print(f"   Cache cost: ${cache_cost:.2f}")
            print(f"   Total cache tokens: {total_cache_tokens:,}")
            print(f"   Effective cache rate: ${effective_cache_rate:.8f} per token")
            print(f"   = ${effective_cache_rate * 1_000_000:.2f} per million tokens")
            
            # Test with this rate
            test_cost = (input_tokens * input_rate + 
                        output_tokens * output_rate + 
                        total_cache_tokens * effective_cache_rate)
            print(f"\n✅ Verification: ${test_cost:.2f} (should equal ${total_cost:.2f})")
        
        break
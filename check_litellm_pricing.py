#!/usr/bin/env python3

import json
import urllib.request

# Fetch LiteLLM pricing data (same as ccusage)
url = 'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json'

try:
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read())
    
    print("🔍 Searching for Claude models in LiteLLM pricing database...")
    print("=" * 60)
    
    # Search for models we're using
    search_terms = ['claude-opus-4', 'claude-sonnet-4', 'claude-4', 'opus-4', 'sonnet-4', '20250514']
    
    found_any = False
    for model_name, model_data in data.items():
        for term in search_terms:
            if term.lower() in model_name.lower():
                found_any = True
                print(f"\n📊 Model: {model_name}")
                if 'input_cost_per_token' in model_data:
                    print(f"   Input: ${model_data['input_cost_per_token']:.8f}/token = ${model_data['input_cost_per_token'] * 1_000_000:.2f}/M")
                if 'output_cost_per_token' in model_data:
                    print(f"   Output: ${model_data['output_cost_per_token']:.8f}/token = ${model_data['output_cost_per_token'] * 1_000_000:.2f}/M")
                if 'cache_creation_input_token_cost' in model_data:
                    print(f"   Cache Create: ${model_data['cache_creation_input_token_cost']:.8f}/token = ${model_data['cache_creation_input_token_cost'] * 1_000_000:.2f}/M")
                if 'cache_read_input_token_cost' in model_data:
                    print(f"   Cache Read: ${model_data['cache_read_input_token_cost']:.8f}/token = ${model_data['cache_read_input_token_cost'] * 1_000_000:.2f}/M")
                break
    
    if not found_any:
        print("❌ No Claude-4 models found in LiteLLM database!")
        print("\n💡 This means ccusage returns null from getModelPricing()!")
        print("   When pricing is null, calculateCostFromTokens returns 0")
        print("   This explains why all costs might be 0!")
        
except Exception as e:
    print(f"Error: {e}")
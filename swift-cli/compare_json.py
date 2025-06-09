#!/usr/bin/env python3

import json
import subprocess
import sys
import time

def run_ccusage_json():
    """Run ccusage with JSON output and extract 2025-06-09 data"""
    try:
        result = subprocess.run(['npx', 'ccusage@latest', 'daily', '--json'], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            print(f"ccusage failed: {result.stderr}", file=sys.stderr)
            return None
            
        data = json.loads(result.stdout)
        
        # Find 2025-06-09 entry
        for entry in data.get('daily', []):
            if entry.get('date') == '2025-06-09':
                return {
                    'tool': 'ccusage',
                    'date': entry['date'],
                    'inputTokens': entry['inputTokens'],
                    'outputTokens': entry['outputTokens'],
                    'cacheCreationTokens': entry['cacheCreationTokens'],
                    'cacheReadTokens': entry['cacheReadTokens'],
                    'totalTokens': entry['totalTokens'],
                    'totalCost': entry.get('totalCost', 0)
                }
        
        print("No data found for 2025-06-09 in ccusage output", file=sys.stderr)
        return None
        
    except subprocess.TimeoutExpired:
        print("ccusage timed out", file=sys.stderr)
        return None
    except json.JSONDecodeError as e:
        print(f"Failed to parse ccusage JSON: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error running ccusage: {e}", file=sys.stderr)
        return None

def run_swift_cli_json():
    """Run Swift CLI with JSON output and extract 2025-06-09 data"""
    try:
        result = subprocess.run(['swift', 'simple_output.swift', '--json'], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            print(f"Swift CLI failed: {result.stderr}", file=sys.stderr)
            return None
            
        data = json.loads(result.stdout)
        
        # Extract data (should be first entry in daily array)
        daily_data = data.get('daily', [])
        if daily_data:
            entry = daily_data[0]
            return {
                'tool': 'swift_cli',
                'date': entry['date'],
                'inputTokens': entry['inputTokens'],
                'outputTokens': entry['outputTokens'],
                'cacheCreationTokens': entry['cacheCreationTokens'],
                'cacheReadTokens': entry['cacheReadTokens'],
                'totalTokens': entry['totalTokens'],
                'totalCost': entry.get('totalCost', 0)
            }
        
        print("No daily data found in Swift CLI output", file=sys.stderr)
        return None
        
    except json.JSONDecodeError as e:
        print(f"Failed to parse Swift CLI JSON: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error running Swift CLI: {e}", file=sys.stderr)
        return None

def compare_results(ccusage_data, swift_data):
    """Compare the two results and output formatted comparison"""
    
    print("🔍 JSON Comparison for 2025-06-09")
    print("==================================")
    
    # Format table
    print(f"{'Metric':<15} {'ccusage':<15} {'Swift CLI':<15} {'Match':<8} {'Diff':<12}")
    print("-" * 70)
    
    metrics = [
        ('Input', 'inputTokens'),
        ('Output', 'outputTokens'),
        ('Cache Create', 'cacheCreationTokens'),
        ('Cache Read', 'cacheReadTokens'),
        ('Total', 'totalTokens')
    ]
    
    all_match = True
    total_diff = 0
    
    for label, key in metrics:
        ccusage_val = ccusage_data.get(key, 0)
        swift_val = swift_data.get(key, 0)
        diff = abs(ccusage_val - swift_val)
        match = "✅" if diff == 0 else "❌"
        
        if diff != 0:
            all_match = False
            total_diff += diff
        
        print(f"{label:<15} {ccusage_val:<15,} {swift_val:<15,} {match:<8} {diff:<12,}")
    
    print("-" * 70)
    
    if all_match:
        print("🎉 PERFECT MATCH! Both tools produce identical results.")
    else:
        ccusage_total = ccusage_data.get('totalTokens', 0)
        if ccusage_total > 0:
            accuracy = (1.0 - total_diff / ccusage_total) * 100
            print(f"📊 Accuracy: {accuracy:.2f}% (Total diff: {total_diff:,} tokens)")
        else:
            print(f"❌ Significant differences found (Total diff: {total_diff:,} tokens)")
    
    return all_match

def main():
    print("🚀 Running JSON-based comparison...")
    print("=====================================")
    
    # Time the operations
    start_time = time.time()
    
    print("📊 Fetching ccusage data...")
    ccusage_data = run_ccusage_json()
    ccusage_time = time.time() - start_time
    
    print("📊 Fetching Swift CLI data...")
    swift_start = time.time()
    swift_data = run_swift_cli_json()
    swift_time = time.time() - swift_start
    
    total_time = time.time() - start_time
    
    if not ccusage_data:
        print("❌ Failed to get ccusage data")
        sys.exit(1)
    
    if not swift_data:
        print("❌ Failed to get Swift CLI data")
        sys.exit(1)
    
    print()
    compare_results(ccusage_data, swift_data)
    
    print(f"\n⏱️  Performance:")
    print(f"   ccusage: {ccusage_time:.2f}s")
    print(f"   Swift CLI: {swift_time:.2f}s")
    print(f"   Total: {total_time:.2f}s")
    
    # Show raw JSON if requested
    if '--debug' in sys.argv:
        print("\n🔍 Raw JSON Data:")
        print("=================")
        print("ccusage:")
        print(json.dumps(ccusage_data, indent=2))
        print("\nSwift CLI:")
        print(json.dumps(swift_data, indent=2))

if __name__ == "__main__":
    main()
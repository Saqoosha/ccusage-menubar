# Future Performance Improvements

## Current Status
- First load: 0.57-0.67 seconds
- Subsequent loads (with ultra-fast mode): Should be < 0.1s (not tested yet)
- Still slower than our CLI benchmark (0.002s)

## Identified Bottlenecks

### 1. File Discovery (0.2-0.25s - 35% of time)
**Problem**: Every time we scan ~/.claude/projects/ recursively
**Solutions**:
- Pre-index files on app launch
- Use FSEvents to track only changed files
- Keep persistent file list in UserDefaults
- Only scan for new files, not all files

### 2. LiteLLM Pricing Fetch (0.02-0.07s - 10% of time)
**Problem**: Network request on every load
**Solutions**:
- Cache pricing data for 24 hours
- Pre-load pricing on app launch
- Use hardcoded fallback prices
- Only fetch if cache is stale

### 3. Processing (0.35s - 55% of time)
**Problem**: Even with 99% cache hits, still takes 0.35s
**Solutions**:
- Keep all data in memory (not just file cache)
- Pre-aggregate daily/monthly totals
- Use more efficient data structures
- Process only changed files

## Ultimate Architecture

```
App Launch:
1. Load all cached data into memory (instant)
2. Start background tasks:
   - Index all JSONL files
   - Fetch pricing data
   - Build initial cache
3. Show UI with cached values immediately

Runtime:
1. FSEvents monitors for new/changed files
2. Only process deltas (new entries)
3. Keep running totals in memory
4. Update UI instantly

Result: True 0.002s updates!
```

## Technical Implementation

### 1. Persistent File Index
```swift
// Save file list to UserDefaults
UserDefaults.standard.set(fileList, forKey: "claudeFileList")
UserDefaults.standard.set(Date(), forKey: "claudeFileListDate")
```

### 2. Background Processing
```swift
// Process in background, update UI on main
Task.detached(priority: .background) {
    // Heavy processing
    await MainActor.run {
        // UI updates
    }
}
```

### 3. Delta Processing
```swift
// Only process new entries since last check
let lastProcessedDate = UserDefaults.standard.object(forKey: "lastProcessedDate") as? Date
// Process only entries after this date
```

## Expected Performance

With all optimizations:
- First launch: < 0.5s (with pre-cached data)
- Subsequent updates: < 0.01s (10ms)
- File changes: < 0.05s (50ms) for delta processing

## Priority Order

1. **High Impact, Easy**: Cache pricing data locally
2. **High Impact, Medium**: Keep file list in memory
3. **High Impact, Hard**: FSEvents + delta processing
4. **Medium Impact, Easy**: Pre-aggregate totals
5. **Low Impact, Hard**: Custom data structures

## Conclusion

While 0.57s is already good, we can achieve true "instant" updates (< 10ms) with these improvements. The key is to eliminate repeated work and keep everything in memory.
# Performance Optimization TODO

## 🎯 Goal: Match ccusage speed (1-2 seconds)

Current: Swift ~15s vs ccusage ~2s = **7.5x slower**

## 📊 Phase 1: Benchmark & Analysis

### 1.1 Create Benchmark Tool
- [ ] Create `swift-cli/benchmark.swift` that measures:
  - Total execution time
  - File discovery time
  - JSON parsing time per file
  - Date formatting time
  - Aggregation time
  - LiteLLM fetch time
- [ ] Compare with ccusage using same timing approach
- [ ] Profile memory usage

### 1.2 Analyze ccusage Implementation
- [ ] Study how ccusage uses `tinyglobby` for fast file discovery
- [ ] Check if ccusage uses streaming or batch processing
- [ ] Understand ccusage's caching strategy
- [ ] See how ccusage handles date formatting efficiently

## 🚀 Phase 2: Quick Wins (Target: 50% improvement)

### 2.1 Parallel Processing
- [ ] Use `TaskGroup` for concurrent file processing
- [ ] Process files in batches of 100-500
- [ ] Benchmark optimal batch size

### 2.2 Optimize Date Formatting
- [ ] Cache date formatter instances
- [ ] Pre-compile regex patterns
- [ ] Use string slicing instead of full date parsing where possible

### 2.3 Smarter File Filtering
- [ ] Skip files older than 30 days at filesystem level
- [ ] Use file modification dates to avoid parsing old data
- [ ] Implement early exit when target date is found

## 🔥 Phase 3: Major Optimizations (Target: Match ccusage)

### 3.1 Streaming JSON Parser
- [ ] Replace JSONSerialization with line-by-line streaming
- [ ] Parse only required fields (skip unused data)
- [ ] Use `Scanner` or custom parser for faster processing

### 3.2 Memory-Mapped Files
- [ ] Use `Data(contentsOf:options:.mappedIfSafe)` for large files
- [ ] Process files without loading entirely into memory
- [ ] Benchmark vs regular file reading

### 3.3 Caching Strategy
- [ ] Cache parsed data with file modification timestamps
- [ ] Store daily aggregates to avoid re-parsing
- [ ] Implement incremental updates (only parse new entries)

### 3.4 Optimize LiteLLM Fetching
- [ ] Cache pricing data locally with 24h expiry
- [ ] Load pricing asynchronously (don't block initial display)
- [ ] Fallback to hardcoded prices if network is slow

## 🧪 Phase 4: Advanced Techniques

### 4.1 SIMD/Accelerate Framework
- [ ] Use Accelerate for bulk numeric operations
- [ ] SIMD for parallel token summation

### 4.2 Custom File Scanner
- [ ] Build optimized JSONL scanner in C/Objective-C
- [ ] Use NSScanner for faster string processing
- [ ] Implement zero-copy parsing where possible

### 4.3 Background Indexing
- [ ] Create background service that pre-indexes files
- [ ] Update index on file changes using FSEvents
- [ ] Query index instead of parsing files on demand

## 📈 Success Metrics

| Metric | Current | Target | 
|--------|---------|---------|
| Initial Load | ~15s | <2s |
| File Discovery | ~3s | <0.5s |
| JSON Parsing | ~10s | <1s |
| LiteLLM Fetch | ~2s | <0.1s (cached) |
| Memory Usage | Unknown | <50MB |

## 🔧 Implementation Order

1. **Benchmark first** - Can't optimize what we don't measure
2. **Parallel processing** - Biggest bang for buck
3. **Streaming parser** - Major performance gain
4. **Caching** - Avoid repeated work
5. **Advanced techniques** - Only if still needed

## 💡 Key Insights

**Why is ccusage fast?**
- Uses Node.js streams (efficient I/O)
- `tinyglobby` is optimized for file discovery
- JavaScript's event loop handles async well
- Possibly caches some data

**Swift advantages we can leverage:**
- True parallelism (not just concurrency)
- Lower memory overhead than Node.js
- Direct system calls
- SIMD/Accelerate for math operations

## 🎬 Next Steps

1. Create benchmark tool
2. Run comparative analysis
3. Implement parallel file processing
4. Test and measure improvement
5. Iterate based on results
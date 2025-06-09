# Future Improvements

## 1. Dynamic Pricing Updates (Like ccusage)

ccusage fetches latest pricing from LiteLLM on every run:
```
WARN  Fetching latest model pricing from LiteLLM...
ℹ Loaded pricing for 1057 models
```

### Pros:
- Always up-to-date pricing
- Supports new models automatically
- No manual updates needed

### Cons:
- Slower startup (network request)
- Requires internet connection
- Adds ~1-2 seconds to launch time

### Potential Implementation:
1. Cache pricing data locally with timestamp
2. Check if cache is older than 24 hours
3. If old, fetch new pricing in background
4. Use cached pricing for immediate display
5. Update display after new pricing loads

### Alternative: Hybrid Approach
- Hard-code common models (Claude, GPT-4)
- Fetch pricing only for unknown models
- Update hard-coded values monthly via app updates

## 2. Performance Optimizations

Current performance:
- ccusage: ~2.1 seconds
- Swift CLI: ~12-15 seconds
- Swift MenuBar: ~15 seconds on first load

### Optimization Ideas:
1. **Parallel file processing** - Process JSONL files concurrently
2. **Streaming JSON parser** - Don't load entire file into memory
3. **Index recent files** - Cache file paths modified in last 30 days
4. **Background refresh** - Start loading immediately, show cached data first
5. **Incremental updates** - Only process new entries since last check

## 3. Additional Features

1. **Historical graphs** - Show usage trends over time
2. **Cost alerts** - Notify when daily/monthly limit exceeded
3. **Model breakdown** - Show cost per model
4. **Export data** - CSV/JSON export for expense reports
5. **Multiple accounts** - Support multiple Claude accounts
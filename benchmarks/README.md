# Swift CLI vs ccusage Comparison Tools

2025-06-09のClaude使用量データを比較するためのツール集

## 🛠️ 利用可能なツール

### 1. Swift CLI (simple_output.swift)
```bash
# 人間が読める形式
swift simple_output.swift

# JSON形式 (ccusage互換)
swift simple_output.swift --json
```

### 2. ccusage CLI
```bash
# 人間が読める形式
npx ccusage@latest daily

# JSON形式
npx ccusage@latest daily --json
```

### 3. JSON比較ツール (compare_json.py)
```bash
# 基本比較
python3 compare_json.py

# デバッグ情報付き
python3 compare_json.py --debug
```

## 📊 比較結果

最新の比較結果（2025-06-09）：

```
🔍 JSON Comparison for 2025-06-09
==================================
Metric          ccusage         Swift CLI       Match    Diff        
----------------------------------------------------------------------
Input           17,758          17,758          ✅        0           
Output          342,169         342,169         ✅        0           
Cache Create    17,453,757      17,453,757      ✅        0           
Cache Read      238,683,782     238,683,782     ✅        0           
Total           256,497,466     256,497,466     ✅        0           
----------------------------------------------------------------------
🎉 PERFECT MATCH! Both tools produce identical results.
```

## ⏱️ パフォーマンス

- **ccusage**: ~2.13秒
- **Swift CLI**: ~14.94秒 (ccusageより7倍遅いが、完全に正確)

## 🎯 精度

Swift CLIの実装は ccusage の計算ロジックを完全に再現し、**100%の精度**を達成しています。
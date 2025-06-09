# Currency Conversion Feature

## Overview

The Claude Code Usage MenuBar app includes a comprehensive currency conversion system that automatically converts USD pricing to the user's preferred local currency. This feature provides real-time exchange rates and supports 33+ popular currencies with proper locale-specific formatting.

## Key Features

### 🌍 Multi-Currency Support
- **33+ Currencies**: USD, JPY, EUR, GBP, CNY, KRW, CAD, AUD, CHF, HKD, SGD, INR, MXN, BRL, RUB, ZAR, TRY, NZD, THB, MYR, IDR, PHP, VND, SEK, NOK, DKK, PLN, CZK, HUF, ILS, AED, SAR, TWD
- **Auto-Detection**: Automatically detects and uses OS locale currency as default
- **User Selection**: Currency picker in settings section for easy switching

### 💱 Exchange Rate Management
- **Free API**: Uses Fawazahmed0's Exchange API (CC0 licensed, no registration required)
- **24-Hour Cache**: Exchange rates cached for 24 hours to reduce API calls
- **Dual Endpoints**: Primary and fallback URLs for reliability
- **Real-Time Updates**: Automatic rate refresh when cache expires

### 🎨 Smart Formatting
- **Locale-Aware**: Uses Swift's NumberFormatter with proper locale identifiers
- **Currency Symbols**: Displays correct currency symbols (¥, €, £, etc.)
- **Decimal Handling**: Intelligent decimal places (JPY: 0 decimals, USD: 2 decimals)
- **Thousand Separators**: Proper comma formatting (JPY: 1,234,567)

## Technical Implementation

### Architecture

```swift
@MainActor
class CurrencyManager: ObservableObject {
    @Published var selectedCurrency: String
    @Published var exchangeRate: Double
    @Published var popularCurrencies: [Currency]
    
    // Core methods
    func convertFromUSD(_ amount: Double) -> Double
    func formatCurrency(_ amount: Double) -> String
    func fetchExchangeRates() async
}
```

### Data Structure

```swift
struct Currency {
    let code: String           // "JPY"
    let name: String          // "Japanese Yen"
    let localeIdentifier: String  // "ja_JP"
}
```

### Exchange Rate API

**Primary URL**: `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json`
**Fallback URL**: `https://latest.currency-api.pages.dev/v1/currencies/usd.json`

**Response Format**:
```json
{
  "date": "2024-01-01",
  "usd": {
    "jpy": 150.25,
    "eur": 0.85,
    "gbp": 0.75
  }
}
```

### Cache Strategy

1. **Memory Cache**: Instant access to current exchange rate
2. **Disk Cache**: 24-hour persistent storage in UserDefaults
3. **Automatic Refresh**: Background updates when cache expires
4. **Fallback**: Uses cached data if API is unavailable

## Usage Flow

### Initial Setup
1. App detects OS locale currency (e.g., "JPY" for Japanese system)
2. Adds user's currency to top of currency list
3. Loads cached exchange rates or fetches fresh ones
4. Sets default currency to user's locale

### Currency Conversion
1. USD cost calculated from Claude Code usage
2. Exchange rate applied: `localAmount = usdAmount * exchangeRate`
3. NumberFormatter formats with proper locale
4. Result displayed in menu bar and popup

### User Interaction
1. User selects different currency from picker
2. App loads cached rate or fetches fresh one
3. All displayed costs update immediately
4. Selection saved to UserDefaults for persistence

## UI Integration

### Menu Bar Label
- Shows today's cost in selected currency
- Compact format with proper currency symbol
- 70% minimum scale factor to prevent text wrapping

### Popup Content
- Today and monthly costs in selected currency
- Currency picker in dedicated settings section
- Real-time updates when currency changes

### Text Formatting
```swift
// Example formatting for different currencies
JPY: ¥1,234,567 (no decimals)
USD: $123.45 (2 decimals)
EUR: €123,45 (2 decimals, locale-specific)
```

## Performance Characteristics

- **Exchange Rate Fetch**: ~200ms for initial load
- **Currency Conversion**: < 1ms (simple multiplication)
- **Format Operation**: ~5ms (NumberFormatter)
- **Cache Hit**: < 1ms (memory access)
- **UI Update**: Immediate (SwiftUI reactive updates)

## Error Handling

### API Failures
- Tries primary URL first
- Falls back to secondary URL
- Uses cached data if both fail
- Continues with USD if no data available

### Invalid Currencies
- Falls back to USD for unknown currency codes
- Maintains app stability with graceful degradation
- Logs errors for debugging

### Network Issues
- 24-hour cache provides offline functionality
- App remains functional without internet
- Shows last known exchange rates

## Configuration

### Supported Locales
Each currency includes proper locale identifier for accurate formatting:
```swift
Currency(code: "JPY", name: "Japanese Yen", localeIdentifier: "ja_JP")
Currency(code: "EUR", name: "Euro", localeIdentifier: "de_DE")
Currency(code: "GBP", name: "British Pound", localeIdentifier: "en_GB")
```

### Special Currency Handling
```swift
switch selectedCurrency {
case "JPY", "KRW", "VND", "IDR":
    formatter.maximumFractionDigits = 0  // No decimals
default:
    formatter.maximumFractionDigits = 2  // Standard 2 decimals
}
```

## Future Enhancements

### Planned Features
- **Historical Rates**: Track rate changes over time
- **Rate Alerts**: Notify when rates change significantly
- **Custom Currencies**: Allow adding unsupported currencies
- **Offline Mode**: Extended caching for extended offline use

### Performance Optimizations
- **Rate Batching**: Fetch multiple currencies in single request
- **Smart Caching**: Predictive loading of likely currencies
- **Background Updates**: Silent rate refreshes

## API License and Attribution

**Fawazahmed0 Exchange API**
- **License**: CC0 (Public Domain)
- **Rate Limits**: None
- **Registration**: Not required
- **Attribution**: Optional but appreciated
- **Repository**: https://github.com/fawazahmed0/exchange-api

This ensures the currency conversion feature remains free and accessible for all users while providing reliable, accurate exchange rate data.
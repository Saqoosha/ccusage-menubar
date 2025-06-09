import Foundation
import SwiftUI

// Currency data structure
struct Currency {
    let code: String
    let name: String
    let localeIdentifier: String
}

@MainActor
class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    
    @Published var selectedCurrency: String {
        didSet {
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
        }
    }
    
    @Published var exchangeRate: Double = 1.0
    @Published var isLoadingRates = false
    @Published var popularCurrencies: [Currency] = []
    
    private let cacheKey = "cachedExchangeRates"
    private let lastUpdatedKey = "exchangeRatesLastUpdated"
    private let cacheExpiration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    init() {
        // Get user's locale currency
        let userCurrencyCode = Locale.current.currency?.identifier ?? "USD"
        
        // Load saved currency preference, fallback to user's currency
        self.selectedCurrency = UserDefaults.standard.string(forKey: "selectedCurrency") 
            ?? userCurrencyCode
        
        // Setup currency list with user's currency
        setupCurrencyList(userCurrency: userCurrencyCode)
        
        // Load cached exchange rate
        loadCachedRate()
        
        // Fetch fresh rates if needed
        Task {
            await checkAndUpdateRates()
        }
    }
    
    private func setupCurrencyList(userCurrency: String) {
        // Base popular currencies with locale identifiers
        var currencies = [
            Currency(code: "USD", name: "US Dollar", localeIdentifier: "en_US"),
            Currency(code: "JPY", name: "Japanese Yen", localeIdentifier: "ja_JP"),
            Currency(code: "EUR", name: "Euro", localeIdentifier: "de_DE"),
            Currency(code: "GBP", name: "British Pound", localeIdentifier: "en_GB"),
            Currency(code: "CNY", name: "Chinese Yuan", localeIdentifier: "zh_CN"),
            Currency(code: "KRW", name: "Korean Won", localeIdentifier: "ko_KR"),
            Currency(code: "CAD", name: "Canadian Dollar", localeIdentifier: "en_CA"),
            Currency(code: "AUD", name: "Australian Dollar", localeIdentifier: "en_AU"),
            Currency(code: "CHF", name: "Swiss Franc", localeIdentifier: "de_CH"),
            Currency(code: "HKD", name: "Hong Kong Dollar", localeIdentifier: "zh_HK"),
            Currency(code: "SGD", name: "Singapore Dollar", localeIdentifier: "en_SG"),
            Currency(code: "INR", name: "Indian Rupee", localeIdentifier: "hi_IN"),
            Currency(code: "MXN", name: "Mexican Peso", localeIdentifier: "es_MX"),
            Currency(code: "BRL", name: "Brazilian Real", localeIdentifier: "pt_BR"),
            Currency(code: "RUB", name: "Russian Ruble", localeIdentifier: "ru_RU"),
            Currency(code: "ZAR", name: "South African Rand", localeIdentifier: "en_ZA"),
            Currency(code: "TRY", name: "Turkish Lira", localeIdentifier: "tr_TR"),
            Currency(code: "NZD", name: "New Zealand Dollar", localeIdentifier: "en_NZ"),
            Currency(code: "THB", name: "Thai Baht", localeIdentifier: "th_TH"),
            Currency(code: "MYR", name: "Malaysian Ringgit", localeIdentifier: "ms_MY"),
            Currency(code: "IDR", name: "Indonesian Rupiah", localeIdentifier: "id_ID"),
            Currency(code: "PHP", name: "Philippine Peso", localeIdentifier: "en_PH"),
            Currency(code: "VND", name: "Vietnamese Dong", localeIdentifier: "vi_VN"),
            Currency(code: "SEK", name: "Swedish Krona", localeIdentifier: "sv_SE"),
            Currency(code: "NOK", name: "Norwegian Krone", localeIdentifier: "nb_NO"),
            Currency(code: "DKK", name: "Danish Krone", localeIdentifier: "da_DK"),
            Currency(code: "PLN", name: "Polish Złoty", localeIdentifier: "pl_PL"),
            Currency(code: "CZK", name: "Czech Koruna", localeIdentifier: "cs_CZ"),
            Currency(code: "HUF", name: "Hungarian Forint", localeIdentifier: "hu_HU"),
            Currency(code: "ILS", name: "Israeli Shekel", localeIdentifier: "he_IL"),
            Currency(code: "AED", name: "UAE Dirham", localeIdentifier: "ar_AE"),
            Currency(code: "SAR", name: "Saudi Riyal", localeIdentifier: "ar_SA"),
            Currency(code: "TWD", name: "Taiwan Dollar", localeIdentifier: "zh_TW")
        ]
        
        // Check if user's currency is already in the list
        if !currencies.contains(where: { $0.code == userCurrency }) {
            // Add user's currency at the beginning
            let userLocale = Locale.current
            if let currencyName = userLocale.localizedString(forCurrencyCode: userCurrency) {
                let userCurrencyObj = Currency(
                    code: userCurrency,
                    name: currencyName,
                    localeIdentifier: userLocale.identifier
                )
                currencies.insert(userCurrencyObj, at: 0)
            }
        } else {
            // Move user's currency to the beginning
            if let index = currencies.firstIndex(where: { $0.code == userCurrency }) {
                let userCurrencyObj = currencies.remove(at: index)
                currencies.insert(userCurrencyObj, at: 0)
            }
        }
        
        self.popularCurrencies = currencies
    }
    
    private func loadCachedRate() {
        if let cached = UserDefaults.standard.data(forKey: cacheKey),
           let rates = try? JSONDecoder().decode([String: Double].self, from: cached),
           let rate = rates[selectedCurrency.lowercased()] {
            self.exchangeRate = rate
        }
    }
    
    func checkAndUpdateRates() async {
        // Check if cache is still valid
        if let lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date {
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdated)
            if timeSinceUpdate < cacheExpiration {
                // Cache is still valid, just load the rate for selected currency
                loadCachedRate()
                return
            }
        }
        
        // Cache expired or doesn't exist, fetch new rates
        await fetchExchangeRates()
    }
    
    func fetchExchangeRates() async {
        isLoadingRates = true
        defer { isLoadingRates = false }
        
        let primaryURL = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"
        let fallbackURL = "https://latest.currency-api.pages.dev/v1/currencies/usd.json"
        
        // Try primary URL first
        if let rates = await fetchFromURL(primaryURL) {
            await saveRates(rates)
            return
        }
        
        // Try fallback URL
        if let rates = await fetchFromURL(fallbackURL) {
            await saveRates(rates)
            return
        }
        
        // Both failed, use cached data if available
        print("Failed to fetch exchange rates, using cache")
        loadCachedRate()
    }
    
    private func fetchFromURL(_ urlString: String) async -> [String: Double]? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            return response.usd
        } catch {
            print("Error fetching rates from \(urlString): \(error)")
            return nil
        }
    }
    
    @MainActor
    private func saveRates(_ rates: [String: Double]) async {
        // Cache the rates
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
        }
        
        // Update current exchange rate
        if let rate = rates[selectedCurrency.lowercased()] {
            self.exchangeRate = rate
        } else if selectedCurrency != "USD" {
            // Currency not found, fallback to USD
            self.exchangeRate = 1.0
            self.selectedCurrency = "USD"
        }
    }
    
    // Convert USD amount to selected currency
    func convertFromUSD(_ amount: Double) -> Double {
        if selectedCurrency == "USD" {
            return amount
        }
        return amount * exchangeRate
    }
    
    // Format currency with proper symbol and decimal places using NumberFormatter
    func formatCurrency(_ amount: Double) -> String {
        let convertedAmount = convertFromUSD(amount)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency
        
        // Find the appropriate locale for the currency
        if let currency = popularCurrencies.first(where: { $0.code == selectedCurrency }) {
            formatter.locale = Locale(identifier: currency.localeIdentifier)
        } else {
            // Fallback: Try to create a locale from the currency code
            // This helps for currencies not in our list
            formatter.locale = Locale.current
            formatter.currencyCode = selectedCurrency
        }
        
        // Special handling for certain currencies
        switch selectedCurrency {
        case "JPY", "KRW", "VND", "IDR":
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        default:
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        }
        
        return formatter.string(from: NSNumber(value: convertedAmount)) ?? ""
    }
    
    // When currency is changed by user
    func currencyChanged() async {
        loadCachedRate()
        // Optionally fetch fresh rates if cache is old
        await checkAndUpdateRates()
    }
}

// Response structure from the API
private struct ExchangeRateResponse: Codable {
    let date: String
    let usd: [String: Double]
}
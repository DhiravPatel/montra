// Package currency is the ISO 4217 registry (code → minor-unit exponent).
// It must stay identical to the montra.currencies seed in
// supabase/migrations/20261104000001_foundation.sql; an integration test
// verifies parity.
package currency

import "sort"

// Currency describes an ISO 4217 currency.
type Currency struct {
	Code     string
	Name     string
	Exponent int
	Symbol   string
	// ReplacedBy is set for retired currencies kept for historical records
	// (they remain Valid but are not Selectable for new records).
	ReplacedBy string
	RetiredOn  string // YYYY-MM-DD
}

// retired currencies: still valid for history (imports, past transactions),
// not offered for new accounts, budgets, goals or preferences.
var retired = map[string][2]string{
	"BGN": {"EUR", "2026-01-01"}, // Bulgaria adopted the euro on 1 January 2026
}

var registry = map[string]Currency{}

func add(code, name string, exp int, symbol string) {
	registry[code] = Currency{Code: code, Name: name, Exponent: exp, Symbol: symbol}
}

func init() {
	for _, c := range []struct {
		code, name string
		exp        int
		sym        string
	}{
		{"AED", "UAE Dirham", 2, ""}, {"AFN", "Afghani", 2, ""}, {"ALL", "Lek", 2, ""}, {"AMD", "Armenian Dram", 2, ""},
		{"AOA", "Kwanza", 2, ""}, {"ARS", "Argentine Peso", 2, ""}, {"AUD", "Australian Dollar", 2, "A$"}, {"AWG", "Aruban Florin", 2, ""},
		{"AZN", "Azerbaijan Manat", 2, ""}, {"BAM", "Convertible Mark", 2, ""}, {"BBD", "Barbados Dollar", 2, ""}, {"BDT", "Taka", 2, "৳"},
		{"BGN", "Bulgarian Lev", 2, ""}, {"BHD", "Bahraini Dinar", 3, ""}, {"BIF", "Burundi Franc", 0, ""}, {"BMD", "Bermudian Dollar", 2, ""},
		{"BND", "Brunei Dollar", 2, ""}, {"BOB", "Boliviano", 2, ""}, {"BRL", "Brazilian Real", 2, "R$"}, {"BSD", "Bahamian Dollar", 2, ""},
		{"BTN", "Ngultrum", 2, ""}, {"BWP", "Pula", 2, ""}, {"BYN", "Belarusian Ruble", 2, ""}, {"BZD", "Belize Dollar", 2, ""},
		{"CAD", "Canadian Dollar", 2, "CA$"}, {"CDF", "Congolese Franc", 2, ""}, {"CHF", "Swiss Franc", 2, ""}, {"CLP", "Chilean Peso", 0, ""},
		{"CNY", "Yuan Renminbi", 2, "¥"}, {"COP", "Colombian Peso", 2, ""}, {"CRC", "Costa Rican Colon", 2, ""}, {"CUP", "Cuban Peso", 2, ""},
		{"CVE", "Cabo Verde Escudo", 2, ""}, {"CZK", "Czech Koruna", 2, ""}, {"DJF", "Djibouti Franc", 0, ""}, {"DKK", "Danish Krone", 2, ""},
		{"DOP", "Dominican Peso", 2, ""}, {"DZD", "Algerian Dinar", 2, ""}, {"EGP", "Egyptian Pound", 2, ""}, {"ERN", "Nakfa", 2, ""},
		{"ETB", "Ethiopian Birr", 2, ""}, {"EUR", "Euro", 2, "€"}, {"FJD", "Fiji Dollar", 2, ""}, {"FKP", "Falkland Islands Pound", 2, ""},
		{"GBP", "Pound Sterling", 2, "£"}, {"GEL", "Lari", 2, ""}, {"GHS", "Ghana Cedi", 2, ""}, {"GIP", "Gibraltar Pound", 2, ""},
		{"GMD", "Dalasi", 2, ""}, {"GNF", "Guinean Franc", 0, ""}, {"GTQ", "Quetzal", 2, ""}, {"GYD", "Guyana Dollar", 2, ""},
		{"HKD", "Hong Kong Dollar", 2, "HK$"}, {"HNL", "Lempira", 2, ""}, {"HTG", "Gourde", 2, ""}, {"HUF", "Forint", 2, ""},
		{"IDR", "Rupiah", 2, ""}, {"ILS", "New Israeli Sheqel", 2, "₪"}, {"INR", "Indian Rupee", 2, "₹"}, {"IQD", "Iraqi Dinar", 3, ""},
		{"IRR", "Iranian Rial", 2, ""}, {"ISK", "Iceland Krona", 0, ""}, {"JMD", "Jamaican Dollar", 2, ""}, {"JOD", "Jordanian Dinar", 3, ""},
		{"JPY", "Yen", 0, "¥"}, {"KES", "Kenyan Shilling", 2, ""}, {"KGS", "Som", 2, ""}, {"KHR", "Riel", 2, ""},
		{"KMF", "Comorian Franc", 0, ""}, {"KPW", "North Korean Won", 2, ""}, {"KRW", "Won", 0, "₩"}, {"KWD", "Kuwaiti Dinar", 3, ""},
		{"KYD", "Cayman Islands Dollar", 2, ""}, {"KZT", "Tenge", 2, ""}, {"LAK", "Lao Kip", 2, ""}, {"LBP", "Lebanese Pound", 2, ""},
		{"LKR", "Sri Lanka Rupee", 2, ""}, {"LRD", "Liberian Dollar", 2, ""}, {"LSL", "Loti", 2, ""}, {"LYD", "Libyan Dinar", 3, ""},
		{"MAD", "Moroccan Dirham", 2, ""}, {"MDL", "Moldovan Leu", 2, ""}, {"MGA", "Malagasy Ariary", 2, ""}, {"MKD", "Denar", 2, ""},
		{"MMK", "Kyat", 2, ""}, {"MNT", "Tugrik", 2, ""}, {"MOP", "Pataca", 2, ""}, {"MRU", "Ouguiya", 2, ""},
		{"MUR", "Mauritius Rupee", 2, ""}, {"MVR", "Rufiyaa", 2, ""}, {"MWK", "Malawi Kwacha", 2, ""}, {"MXN", "Mexican Peso", 2, "MX$"},
		{"MYR", "Malaysian Ringgit", 2, ""}, {"MZN", "Mozambique Metical", 2, ""}, {"NAD", "Namibia Dollar", 2, ""}, {"NGN", "Naira", 2, "₦"},
		{"NIO", "Cordoba Oro", 2, ""}, {"NOK", "Norwegian Krone", 2, ""}, {"NPR", "Nepalese Rupee", 2, ""}, {"NZD", "New Zealand Dollar", 2, "NZ$"},
		{"OMR", "Rial Omani", 3, ""}, {"PAB", "Balboa", 2, ""}, {"PEN", "Sol", 2, ""}, {"PGK", "Kina", 2, ""},
		{"PHP", "Philippine Peso", 2, "₱"}, {"PKR", "Pakistan Rupee", 2, ""}, {"PLN", "Zloty", 2, ""}, {"PYG", "Guarani", 0, ""},
		{"QAR", "Qatari Rial", 2, ""}, {"RON", "Romanian Leu", 2, ""}, {"RSD", "Serbian Dinar", 2, ""}, {"RUB", "Russian Ruble", 2, ""},
		{"RWF", "Rwanda Franc", 0, ""}, {"SAR", "Saudi Riyal", 2, ""}, {"SBD", "Solomon Islands Dollar", 2, ""}, {"SCR", "Seychelles Rupee", 2, ""},
		{"SDG", "Sudanese Pound", 2, ""}, {"SEK", "Swedish Krona", 2, ""}, {"SGD", "Singapore Dollar", 2, "S$"}, {"SHP", "Saint Helena Pound", 2, ""},
		{"SLE", "Leone", 2, ""}, {"SOS", "Somali Shilling", 2, ""}, {"SRD", "Surinam Dollar", 2, ""}, {"SSP", "South Sudanese Pound", 2, ""},
		{"STN", "Dobra", 2, ""}, {"SYP", "Syrian Pound", 2, ""}, {"SZL", "Lilangeni", 2, ""}, {"THB", "Baht", 2, "฿"},
		{"TJS", "Somoni", 2, ""}, {"TMT", "Turkmenistan New Manat", 2, ""}, {"TND", "Tunisian Dinar", 3, ""}, {"TOP", "Pa'anga", 2, ""},
		{"TRY", "Turkish Lira", 2, ""}, {"TTD", "Trinidad and Tobago Dollar", 2, ""}, {"TWD", "New Taiwan Dollar", 2, "NT$"}, {"TZS", "Tanzanian Shilling", 2, ""},
		{"UAH", "Hryvnia", 2, ""}, {"UGX", "Uganda Shilling", 0, ""}, {"USD", "US Dollar", 2, "$"}, {"UYU", "Peso Uruguayo", 2, ""},
		{"UZS", "Uzbekistan Sum", 2, ""}, {"VES", "Bolivar Soberano", 2, ""}, {"VND", "Dong", 0, "₫"}, {"VUV", "Vatu", 0, ""},
		{"WST", "Tala", 2, ""}, {"XAF", "CFA Franc BEAC", 0, ""}, {"XCD", "East Caribbean Dollar", 2, ""}, {"XCG", "Caribbean Guilder", 2, ""},
		{"XOF", "CFA Franc BCEAO", 0, ""}, {"XPF", "CFP Franc", 0, ""}, {"YER", "Yemeni Rial", 2, ""}, {"ZAR", "Rand", 2, "R"},
		{"ZMW", "Zambian Kwacha", 2, ""}, {"ZWG", "Zimbabwe Gold", 2, ""},
	} {
		add(c.code, c.name, c.exp, c.sym)
	}
	for code, r := range retired {
		c := registry[code]
		c.ReplacedBy, c.RetiredOn = r[0], r[1]
		registry[code] = c
	}
}

// Lookup returns the currency for an ISO code.
func Lookup(code string) (Currency, bool) {
	c, ok := registry[code]
	return c, ok
}

// Valid reports whether code is a supported ISO 4217 code.
func Valid(code string) bool {
	_, ok := registry[code]
	return ok
}

// Selectable reports whether code may be chosen for new records (valid and
// not retired).
func Selectable(code string) bool {
	c, ok := registry[code]
	return ok && c.ReplacedBy == ""
}

// Exponent returns the minor-unit exponent, or -1 if unknown.
func Exponent(code string) int {
	if c, ok := registry[code]; ok {
		return c.Exponent
	}
	return -1
}

// All returns all currencies sorted by code.
func All() []Currency {
	out := make([]Currency, 0, len(registry))
	for _, c := range registry {
		out = append(out, c)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Code < out[j].Code })
	return out
}

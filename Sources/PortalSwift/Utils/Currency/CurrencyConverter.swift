//
//  CurrencyConverter.swift
//  PortalSwift
//
//  Created by Blake Williams on 6/1/23.
//

import Foundation

public enum CurrencyConverterError: LocalizedError {
  case invalidCountryCode
  case invalidCurrencyCode
}

class CurrencyConverter {
  private let countryCodes: [String: String] = [
    "AD": "Andorra",
    "AE": "United Arab Emirates",
    "AF": "Afghanistan",
    "AG": "Antigua and Barbuda",
    "AI": "Anguilla",
    "AL": "Albania",
    "AM": "Armenia",
    "AN": "Netherlands Antilles",
    "AO": "Angola",
    "AQ": "Antarctica",
    "AR": "Argentina",
    "AS": "American Samoa",
    "AT": "Austria",
    "AU": "Australia",
    "AW": "Aruba",
    "AZ": "Azerbaijan",
    "BA": "Bosnia and Herzegovina",
    "BB": "Barbados",
    "BD": "Bangladesh",
    "BE": "Belgium",
    "BF": "Burkina Faso",
    "BG": "Bulgaria",
    "BH": "Bahrain",
    "BI": "Burundi",
    "BJ": "Benin",
    "BM": "Bermuda",
    "BN": "Brunei",
    "BO": "Bolivia",
    "BR": "Brazil",
    "BS": "Bahamas",
    "BT": "Bhutan",
    "BV": "Bouvet Island",
    "BW": "Botswana",
    "BY": "Belarus",
    "BZ": "Belize",
    "CA": "Canada",
    "CC": "Cocos (Keeling) Islands",
    "CD": "The Democratic Republic of Congo",
    "CF": "Central African Republic",
    "CG": "Congo",
    "CH": "Switzerland",
    "CI": "Ivory Coast",
    "CK": "Cook Islands",
    "CL": "Chile",
    "CM": "Cameroon",
    "CN": "China",
    "CO": "Colombia",
    "CR": "Costa Rica",
    "CU": "Cuba",
    "CV": "Cape Verde",
    "CX": "Christmas Island",
    "CY": "Cyprus",
    "CZ": "Czech Republic",
    "DE": "Germany",
    "DJ": "Djibouti",
    "DK": "Denmark",
    "DM": "Dominica",
    "DO": "Dominican Republic",
    "DZ": "Algeria",
    "EC": "Ecuador",
    "EE": "Estonia",
    "EG": "Egypt",
    "EH": "Western Sahara",
    "ER": "Eritrea",
    "ES": "Spain",
    "ET": "Ethiopia",
    "FI": "Finland",
    "FJ": "Fiji Islands",
    "FK": "Falkland Islands",
    "FM": "Micronesia, Federated States of",
    "FO": "Faroe Islands",
    "FR": "France",
    "GA": "Gabon",
    "GB": "Northern Ireland",
    "GD": "Grenada",
    "GE": "Georgia",
    "GF": "French Guiana",
    "GG": "Guernsey",
    "GH": "Ghana",
    "GI": "Gibraltar",
    "GL": "Greenland",
    "GM": "Gambia",
    "GN": "Guinea",
    "GP": "Guadeloupe",
    "GQ": "Equatorial Guinea",
    "GR": "Greece",
    "GS": "South Georgia and the South Sandwich Islands",
    "GT": "Guatemala",
    "GU": "Guam",
    "GW": "Guinea-Bissau",
    "GY": "Guyana",
    "HK": "Hong Kong",
    "HM": "Heard Island and McDonald Islands",
    "HN": "Honduras",
    "HR": "Croatia",
    "HT": "Haiti",
    "HU": "Hungary",
    "ID": "Indonesia",
    "IE": "Ireland",
    "IL": "Israel",
    "IM": "Isle of Man",
    "IN": "India",
    "IO": "British Indian Ocean Territory",
    "IQ": "Iraq",
    "IR": "Iran",
    "IS": "Iceland",
    "IT": "Italy",
    "JE": "Jersey",
    "JM": "Jamaica",
    "JO": "Jordan",
    "JP": "Japan",
    "KE": "Kenya",
    "KG": "Kyrgyzstan",
    "KH": "Cambodia",
    "KI": "Kiribati",
    "KM": "Comoros",
    "KN": "Saint Kitts and Nevis",
    "KP": "North Korea",
    "KR": "South Korea",
    "KW": "Kuwait",
    "KY": "Cayman Islands",
    "KZ": "Kazakhstan",
    "LA": "Laos",
    "LB": "Lebanon",
    "LC": "Saint Lucia",
    "LI": "Liechtenstein",
    "LK": "Sri Lanka",
    "LR": "Liberia",
    "LS": "Lesotho",
    "LT": "Lithuania",
    "LU": "Luxembourg",
    "LV": "Latvia",
    "LY": "Libyan Arab Jamahiriya",
    "MA": "Morocco",
    "MC": "Monaco",
    "MD": "Moldova",
    "ME": "Montenegro",
    "MG": "Madagascar",
    "MH": "Marshall Islands",
    "MK": "North Macedonia",
    "ML": "Mali",
    "MM": "Myanmar",
    "MN": "Mongolia",
    "MO": "Macao",
    "MP": "Northern Mariana Islands",
    "MQ": "Martinique",
    "MR": "Mauritania",
    "MS": "Montserrat",
    "MT": "Malta",
    "MU": "Mauritius",
    "MV": "Maldives",
    "MW": "Malawi",
    "MX": "Mexico",
    "MY": "Malaysia",
    "MZ": "Mozambique",
    "NA": "Namibia",
    "NC": "New Caledonia",
    "NE": "Niger",
    "NF": "Norfolk Island",
    "NG": "Nigeria",
    "NI": "Nicaragua",
    "NL": "Netherlands",
    "NO": "Norway",
    "NP": "Nepal",
    "NR": "Nauru",
    "NU": "Niue",
    "NZ": "New Zealand",
    "OM": "Oman",
    "PA": "Panama",
    "PE": "Peru",
    "PF": "French Polynesia",
    "PG": "Papua New Guinea",
    "PH": "Philippines",
    "PK": "Pakistan",
    "PL": "Poland",
    "PM": "Saint Pierre and Miquelon",
    "PN": "Pitcairn",
    "PR": "Puerto Rico",
    "PS": "Palestine",
    "PT": "Portugal",
    "PW": "Palau",
    "PY": "Paraguay",
    "QA": "Qatar",
    "RE": "Reunion",
    "RO": "Romania",
    "RS": "Serbia",
    "RU": "Russian Federation",
    "RW": "Rwanda",
    "SA": "Saudi Arabia",
    "SB": "Solomon Islands",
    "SC": "Seychelles",
    "SD": "Sudan",
    "SE": "Sweden",
    "SG": "Singapore",
    "SH": "Saint Helena",
    "SI": "Slovenia",
    "SJ": "Svalbard and Jan Mayen",
    "SK": "Slovakia",
    "SL": "Sierra Leone",
    "SM": "San Marino",
    "SN": "Senegal",
    "SO": "Somalia",
    "SR": "Suriname",
    "SS": "South Sudan",
    "ST": "Sao Tome and Principe",
    "SV": "El Salvador",
    "SY": "Syria",
    "SZ": "Swaziland",
    "TC": "Turks and Caicos Islands",
    "TD": "Chad",
    "TF": "French Southern territories",
    "TG": "Togo",
    "TH": "Thailand",
    "TJ": "Tajikistan",
    "TK": "Tokelau",
    "TL": "Timor-Leste",
    "TM": "Turkmenistan",
    "TN": "Tunisia",
    "TO": "Tonga",
    "TP": "East Timor",
    "TR": "Turkey",
    "TT": "Trinidad and Tobago",
    "TV": "Tuvalu",
    "TZ": "Tanzania",
    "UA": "Ukraine",
    "UG": "Uganda",
    "UK": "United Kingdom",
    "UM": "United States Minor Outlying Islands",
    "US": "United States",
    "UY": "Uruguay",
    "UZ": "Uzbekistan",
    "VA": "Holy See (Vatican City State)",
    "VC": "Saint Vincent and the Grenadines",
    "VE": "Venezuela",
    "VG": "Virgin Islands, British",
    "VI": "Virgin Islands, U.S.",
    "VN": "Vietnam",
    "VU": "Vanuatu",
    "WF": "Wallis and Futuna",
    "WS": "Samoa",
    "YE": "Yemen",
    "YT": "Mayotte",
    "ZA": "South Africa",
    "ZM": "Zambia",
    "ZW": "Zimbabwe"
  ]

  private let currencyCodes: [String: String] = [
    "Afghanistan": "AFN",
    "Albania": "ALL",
    "Algeria": "DZD",
    "American Samoa": "USD",
    "Andorra": "EUR",
    "Angola": "AOA",
    "Anguilla": "XCD",
    "Antarctica": "XCD",
    "Antigua and Barbuda": "XCD",
    "Argentina": "ARS",
    "Armenia": "AMD",
    "Aruba": "AWG",
    "Australia": "AUD",
    "Austria": "EUR",
    "Azerbaijan": "AZN",
    "Bahamas": "BSD",
    "Bahrain": "BHD",
    "Bangladesh": "BDT",
    "Barbados": "BBD",
    "Belarus": "BYR",
    "Belgium": "EUR",
    "Belize": "BZD",
    "Benin": "XOF",
    "Bermuda": "BMD",
    "Bhutan": "BTN",
    "Bolivia": "BOB",
    "Bosnia and Herzegovina": "BAM",
    "Botswana": "BWP",
    "Bouvet Island": "NOK",
    "Brazil": "BRL",
    "British Indian Ocean Territory": "USD",
    "Brunei": "BND",
    "Bulgaria": "BGN",
    "Burkina Faso": "XOF",
    "Burundi": "BIF",
    "Cambodia": "KHR",
    "Cameroon": "XAF",
    "Canada": "CAD",
    "Cape Verde": "CVE",
    "Cayman Islands": "KYD",
    "Central African Republic": "XAF",
    "Chad": "XAF",
    "Chile": "CLP",
    "China": "CNY",
    "Christmas Island": "AUD",
    "Cocos (Keeling) Islands": "AUD",
    "Colombia": "COP",
    "Comoros": "KMF",
    "Congo": "XAF",
    "Cook Islands": "NZD",
    "Costa Rica": "CRC",
    "Croatia": "HRK",
    "Cuba": "CUP",
    "Cyprus": "EUR",
    "Czech Republic": "CZK",
    "Denmark": "DKK",
    "Djibouti": "DJF",
    "Dominica": "XCD",
    "Dominican Republic": "DOP",
    "East Timor": "USD",
    "Ecuador": "ECS",
    "Egypt": "EGP",
    "El Salvador": "SVC",
    "England": "GBP",
    "Equatorial Guinea": "XAF",
    "Eritrea": "ERN",
    "Estonia": "EUR",
    "Ethiopia": "ETB",
    "Falkland Islands": "FKP",
    "Faroe Islands": "DKK",
    "Fiji Islands": "FJD",
    "Finland": "EUR",
    "France": "EUR",
    "French Guiana": "EUR",
    "French Polynesia": "XPF",
    "French Southern territories": "EUR",
    "Gabon": "XAF",
    "Gambia": "GMD",
    "Georgia": "GEL",
    "Germany": "EUR",
    "Ghana": "GHS",
    "Gibraltar": "GIP",
    "Greece": "EUR",
    "Greenland": "DKK",
    "Grenada": "XCD",
    "Guadeloupe": "EUR",
    "Guam": "USD",
    "Guatemala": "QTQ",
    "Guinea": "GNF",
    "Guinea-Bissau": "CFA",
    "Guyana": "GYD",
    "Haiti": "HTG",
    "Heard Island and McDonald Islands": "AUD",
    "Holy See (Vatican City State)": "EUR",
    "Honduras": "HNL",
    "Hong Kong": "HKD",
    "Hungary": "HUF",
    "Iceland": "ISK",
    "India": "INR",
    "Indonesia": "IDR",
    "Iran": "IRR",
    "Iraq": "IQD",
    "Ireland": "EUR",
    "Israel": "ILS",
    "Italy": "EUR",
    "Ivory Coast": "XOF",
    "Jamaica": "JMD",
    "Japan": "JPY",
    "Jordan": "JOD",
    "Kazakhstan": "KZT",
    "Kenya": "KES",
    "Kiribati": "AUD",
    "Kuwait": "KWD",
    "Kyrgyzstan": "KGS",
    "Laos": "LAK",
    "Latvia": "LVL",
    "Lebanon": "LBP",
    "Lesotho": "LSL",
    "Liberia": "LRD",
    "Libyan Arab Jamahiriya": "LYD",
    "Liechtenstein": "CHF",
    "Lithuania": "LTL",
    "Luxembourg": "EUR",
    "Macao": "MOP",
    "North Macedonia": "MKD",
    "Madagascar": "MGF",
    "Malawi": "MWK",
    "Malaysia": "MYR",
    "Maldives": "MVR",
    "Mali": "XOF",
    "Malta": "EUR",
    "Marshall Islands": "USD",
    "Martinique": "EUR",
    "Mauritania": "MRO",
    "Mauritius": "MUR",
    "Mayotte": "EUR",
    "Mexico": "MXN",
    "Micronesia, Federated States of": "USD",
    "Moldova": "MDL",
    "Monaco": "EUR",
    "Mongolia": "MNT",
    "Montserrat": "XCD",
    "Morocco": "MAD",
    "Mozambique": "MZN",
    "Myanmar": "MMR",
    "Namibia": "NAD",
    "Nauru": "AUD",
    "Nepal": "NPR",
    "Netherlands": "EUR",
    "Netherlands Antilles": "ANG",
    "New Caledonia": "XPF",
    "New Zealand": "NZD",
    "Nicaragua": "NIO",
    "Niger": "XOF",
    "Nigeria": "NGN",
    "Niue": "NZD",
    "Norfolk Island": "AUD",
    "North Korea": "KPW",
    "Northern Ireland": "GBP",
    "Northern Mariana Islands": "USD",
    "Norway": "NOK",
    "Oman": "OMR",
    "Pakistan": "PKR",
    "Palau": "USD",
    "Panama": "PAB",
    "Papua New Guinea": "PGK",
    "Paraguay": "PYG",
    "Peru": "PEN",
    "Philippines": "PHP",
    "Pitcairn": "NZD",
    "Poland": "PLN",
    "Portugal": "EUR",
    "Puerto Rico": "USD",
    "Qatar": "QAR",
    "Reunion": "EUR",
    "Romania": "RON",
    "Russian Federation": "RUB",
    "Rwanda": "RWF",
    "Saint Helena": "SHP",
    "Saint Kitts and Nevis": "XCD",
    "Saint Lucia": "XCD",
    "Saint Pierre and Miquelon": "EUR",
    "Saint Vincent and the Grenadines": "XCD",
    "Samoa": "WST",
    "San Marino": "EUR",
    "Sao Tome and Principe": "STD",
    "Saudi Arabia": "SAR",
    "Scotland": "GBP",
    "Senegal": "XOF",
    "Serbia": "RSD",
    "Seychelles": "SCR",
    "Sierra Leone": "SLL",
    "Singapore": "SGD",
    "Slovakia": "EUR",
    "Slovenia": "EUR",
    "Solomon Islands": "SBD",
    "Somalia": "SOS",
    "South Africa": "ZAR",
    "South Georgia and the South Sandwich Islands": "GBP",
    "South Korea": "KRW",
    "South Sudan": "SSP",
    "Spain": "EUR",
    "Sri Lanka": "LKR",
    "Sudan": "SDG",
    "Suriname": "SRD",
    "Svalbard and Jan Mayen": "NOK",
    "Swaziland": "SZL",
    "Sweden": "SEK",
    "Switzerland": "CHF",
    "Syria": "SYP",
    "Tajikistan": "TJS",
    "Tanzania": "TZS",
    "Thailand": "THB",
    "The Democratic Republic of Congo": "CDF",
    "Togo": "XOF",
    "Tokelau": "NZD",
    "Tonga": "TOP",
    "Trinidad and Tobago": "TTD",
    "Tunisia": "TND",
    "Turkey": "TRY",
    "Turkmenistan": "TMT",
    "Turks and Caicos Islands": "USD",
    "Tuvalu": "AUD",
    "Uganda": "UGX",
    "Ukraine": "UAH",
    "United Arab Emirates": "AED",
    "United Kingdom": "GBP",
    "United States": "USD",
    "United States Minor Outlying Islands": "USD",
    "Uruguay": "UYU",
    "Uzbekistan": "UZS",
    "Vanuatu": "VUV",
    "Venezuela": "VEF",
    "Vietnam": "VND",
    "Virgin Islands, British": "USD",
    "Virgin Islands, U.S.": "USD",
    "Wales": "GBP",
    "Wallis and Futuna": "XPF",
    "Western Sahara": "MAD",
    "Yemen": "YER",
    "Zambia": "ZMW",
    "Zimbabwe": "ZWD"
  ]

  private var requester = HttpRequester(baseUrl: "https://min-api.cryptocompare.com/data/price")

  func fromLocalCurrency(
    _ value: Double,
    _ to: String = "ETH",
    _ countryCode: String = "US",
    completion: @escaping (Result<Double>) -> Any?
  ) {
    let country = self.countryCodes[countryCode]
    if country == nil {
      _ = completion(Result(error: CurrencyConverterError.invalidCountryCode))
      return
    }

    let currency = self.currencyCodes[country!]
    if currency == nil {
      _ = completion(Result(error: CurrencyConverterError.invalidCountryCode))
      return
    }

    do {
      try self.requester.get(
        path: "?fsym=\(currency!)&tsyms=\(to)",
        headers: [:],
        requestType: HttpRequestType.CustomRequest
      ) { (result: Result<[String: Double]>) in
        if result.error != nil {
          _ = completion(Result(error: result.error!))
          return
        }

        guard let conversionRate = result.data![to] else {
          _ = completion(Result(error: CurrencyConverterError.invalidCurrencyCode))
          return
        }

        let valueDecimal = Decimal(value)
        let conversionRateDecimal = Decimal(conversionRate)
        let convertedValueDecimal = (valueDecimal / (1 / conversionRateDecimal))

        let roundingBehavior = NSDecimalNumberHandler(
          roundingMode: .plain,
          scale: 4,
          raiseOnExactness: false,
          raiseOnOverflow: false,
          raiseOnUnderflow: false,
          raiseOnDivideByZero: false
        )

        let convertedValueNSDecimal = NSDecimalNumber(decimal: convertedValueDecimal)
        let roundedValueNSDecimal = convertedValueNSDecimal.rounding(accordingToBehavior: roundingBehavior)
        let roundedValueDouble = roundedValueNSDecimal.doubleValue

        _ = completion(Result(data: roundedValueDouble))
      }
    } catch {
      _ = completion(Result(error: error))
      return
    }
  }

  func toLocalCurrency(
    _ value: Double,
    _ from: String = "ETH",
    _ countryCode: String = "US",
    completion: @escaping (Result<Double>) -> Any?
  ) {
    let country = self.countryCodes[countryCode]
    if country == nil {
      _ = completion(Result(error: CurrencyConverterError.invalidCountryCode))
      return
    }

    let currency = self.currencyCodes[country!]
    if currency == nil {
      _ = completion(Result(error: CurrencyConverterError.invalidCountryCode))
      return
    }

    do {
      try self.requester.get(
        path: "?fsym=\(from)&tsyms=\(currency!)",
        headers: [:],
        requestType: HttpRequestType.CustomRequest
      ) { (result: Result<[String: Double]>) in
        if result.error != nil {
          _ = completion(Result(error: result.error!))
          return
        }

        guard let conversionRate = result.data![currency!] else {
          _ = completion(Result(error: CurrencyConverterError.invalidCurrencyCode))
          return
        }

        let convertedValue = ((value * conversionRate) * 10000).rounded() / 10000.0
        let convertedValueDouble = Double(convertedValue)

        _ = completion(Result(data: convertedValueDouble))
      }
    } catch {
      _ = completion(Result(error: error))
      return
    }
  }
}

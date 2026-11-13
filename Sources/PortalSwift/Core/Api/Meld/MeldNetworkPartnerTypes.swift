//
//  MeldNetworkPartnerTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Countries

public struct MeldNetworkPartnerCountry: Codable, Equatable {
  public let countryCode: String
  public let name: String
  /// A URL of the country's flag.
  public let flag: String?
  public let subdivisions: [String]

  public init(countryCode: String, name: String, flag: String? = nil, subdivisions: [String]) {
    self.countryCode = countryCode
    self.name = name
    self.flag = flag
    self.subdivisions = subdivisions
  }
}

public struct MeldNetworkPartnerCountriesResult: Codable, Equatable {
  public let countries: [MeldNetworkPartnerCountry]

  public init(countries: [MeldNetworkPartnerCountry]) {
    self.countries = countries
  }
}

// MARK: - Currencies

/// A fiat or crypto currency. Crypto currency codes are per chain (`USDC` on Ethereum,
/// `USDC_BASE` on Base): use `chainId` to pick a wallet address on the right chain.
public struct MeldNetworkPartnerCurrency: Codable, Equatable {
  public let currencyCode: String
  public let name: String
  public let decimalPlaces: Int
  public let type: MeldCurrencyType
  public let chainCode: String?
  /// The chain id as Meld reports it, e.g. `"1"` for Ethereum or `"8453"` for Base.
  public let chainId: String?
  public let contract: String?
  /// A URL of the currency's symbol.
  public let symbol: String

  public init(
    currencyCode: String,
    name: String,
    decimalPlaces: Int,
    type: MeldCurrencyType,
    chainCode: String? = nil,
    chainId: String? = nil,
    contract: String? = nil,
    symbol: String
  ) {
    self.currencyCode = currencyCode
    self.name = name
    self.decimalPlaces = decimalPlaces
    self.type = type
    self.chainCode = chainCode
    self.chainId = chainId
    self.contract = contract
    self.symbol = symbol
  }
}

public struct MeldNetworkPartnerCurrenciesResult: Codable, Equatable {
  public let currencies: [MeldNetworkPartnerCurrency]

  public init(currencies: [MeldNetworkPartnerCurrency]) {
    self.currencies = currencies
  }
}

// MARK: - Limits

/// The fiat amount range one provider accepts for one payment method.
public struct MeldNetworkPartnerFiatLimit: Codable, Equatable {
  public let provider: String
  public let category: MeldCategory?
  public let countryCode: String
  public let currencyCode: String
  public let paymentMethod: String
  public let min: Double
  public let max: Double

  public init(
    provider: String,
    category: MeldCategory? = nil,
    countryCode: String,
    currencyCode: String,
    paymentMethod: String,
    min: Double,
    max: Double
  ) {
    self.provider = provider
    self.category = category
    self.countryCode = countryCode
    self.currencyCode = currencyCode
    self.paymentMethod = paymentMethod
    self.min = min
    self.max = max
  }
}

public struct MeldNetworkPartnerFiatLimitsResult: Codable, Equatable {
  public let fiatLimits: [MeldNetworkPartnerFiatLimit]

  public init(fiatLimits: [MeldNetworkPartnerFiatLimit]) {
    self.fiatLimits = fiatLimits
  }
}

/// How much a customer can transact per period at each KYC level.
public struct MeldNetworkPartnerKycLimit: Codable, Equatable {
  public let provider: String
  public let category: MeldCategory?
  public let countryCode: String
  public let limitType: MeldLimitType
  public let currencyCode: String
  public let level1: Double
  public let level2: Double
  public let level3: Double

  public init(
    provider: String,
    category: MeldCategory? = nil,
    countryCode: String,
    limitType: MeldLimitType,
    currencyCode: String,
    level1: Double,
    level2: Double,
    level3: Double
  ) {
    self.provider = provider
    self.category = category
    self.countryCode = countryCode
    self.limitType = limitType
    self.currencyCode = currencyCode
    self.level1 = level1
    self.level2 = level2
    self.level3 = level3
  }
}

public struct MeldNetworkPartnerKycLimitsResult: Codable, Equatable {
  public let kycLimits: [MeldNetworkPartnerKycLimit]

  public init(kycLimits: [MeldNetworkPartnerKycLimit]) {
    self.kycLimits = kycLimits
  }
}

// MARK: - Partners

/// A service provider Meld routes to.
public struct MeldNetworkPartner: Codable, Equatable {
  /// The id to pass as `MeldSessionData.serviceProvider` or in `partners` filters.
  public let serviceProvider: String
  public let name: String
  public let status: MeldPartnerStatus
  public let categories: [MeldCategory]
  public let capabilities: [Capability]
  public let url: String?
  public let isExchange: Bool?
  public let kycMode: String?
  public let lastLoadedAt: String?
  public let logo: Logo
  public let headless: Headless

  public struct Capability: Codable, Equatable {
    public let category: MeldCategory
    public let domains: [MeldPartnerDomain]
    public let status: MeldPartnerStatus

    public init(category: MeldCategory, domains: [MeldPartnerDomain], status: MeldPartnerStatus) {
      self.category = category
      self.domains = domains
      self.status = status
    }
  }

  public struct Logo: Codable, Equatable {
    public let dark: String
    public let light: String
    public let darkShort: String
    public let lightShort: String

    public init(dark: String, light: String, darkShort: String, lightShort: String) {
      self.dark = dark
      self.light = light
      self.darkShort = darkShort
      self.lightShort = lightShort
    }
  }

  public struct Headless: Codable, Equatable {
    public let supported: Bool
    public let kycMode: String?
    public let uiCustomization: Bool

    public init(supported: Bool, kycMode: String? = nil, uiCustomization: Bool) {
      self.supported = supported
      self.kycMode = kycMode
      self.uiCustomization = uiCustomization
    }
  }

  public init(
    serviceProvider: String,
    name: String,
    status: MeldPartnerStatus,
    categories: [MeldCategory],
    capabilities: [Capability],
    url: String? = nil,
    isExchange: Bool? = nil,
    kycMode: String? = nil,
    lastLoadedAt: String? = nil,
    logo: Logo,
    headless: Headless
  ) {
    self.serviceProvider = serviceProvider
    self.name = name
    self.status = status
    self.categories = categories
    self.capabilities = capabilities
    self.url = url
    self.isExchange = isExchange
    self.kycMode = kycMode
    self.lastLoadedAt = lastLoadedAt
    self.logo = logo
    self.headless = headless
  }
}

// MARK: - Payment methods

public struct MeldNetworkPartnerPaymentMethod: Codable, Equatable {
  public let countryCode: String
  /// The provider's own name for the method, e.g. `credit_debit_card`.
  public let providerMethod: String
  /// Meld's name for the method, the value quotes use as `paymentMethodType`, e.g.
  /// `CREDIT_DEBIT_CARD`.
  public let method: String
  public let name: String
  public let type: MeldPaymentType
  public let logo: MeldLogo
  public let headlessSupported: Bool?
  public let cardRenderMode: MeldCardRenderMode?

  public init(
    countryCode: String,
    providerMethod: String,
    method: String,
    name: String,
    type: MeldPaymentType,
    logo: MeldLogo,
    headlessSupported: Bool? = nil,
    cardRenderMode: MeldCardRenderMode? = nil
  ) {
    self.countryCode = countryCode
    self.providerMethod = providerMethod
    self.method = method
    self.name = name
    self.type = type
    self.logo = logo
    self.headlessSupported = headlessSupported
    self.cardRenderMode = cardRenderMode
  }
}

// MARK: - Routes

/// What one partner supports for a source and destination currency pair.
public struct MeldNetworkPartnerRoute: Codable, Equatable {
  public let partner: String
  public let source: String
  public let destination: String
  public let paymentMethods: [PaymentMethod]
  public let kycLimits: [MeldNetworkPartnerKycLimit]

  public struct PaymentMethod: Codable, Equatable {
    public let paymentType: MeldPaymentType
    /// Meld's name for the method, e.g. `CREDIT_DEBIT_CARD`.
    public let name: String
    public let partnerMethodName: String?
    public let limits: Limits?
    public let logo: MeldLogo
    public let headlessSupported: Bool?
    public let cardRenderMode: MeldCardRenderMode?

    public init(
      paymentType: MeldPaymentType,
      name: String,
      partnerMethodName: String? = nil,
      limits: Limits? = nil,
      logo: MeldLogo,
      headlessSupported: Bool? = nil,
      cardRenderMode: MeldCardRenderMode? = nil
    ) {
      self.paymentType = paymentType
      self.name = name
      self.partnerMethodName = partnerMethodName
      self.limits = limits
      self.logo = logo
      self.headlessSupported = headlessSupported
      self.cardRenderMode = cardRenderMode
    }
  }

  public struct Limits: Codable, Equatable {
    public let currencyCode: String
    public let min: Double
    public let max: Double

    public init(currencyCode: String, min: Double, max: Double) {
      self.currencyCode = currencyCode
      self.min = min
      self.max = max
    }
  }

  public init(
    partner: String,
    source: String,
    destination: String,
    paymentMethods: [PaymentMethod],
    kycLimits: [MeldNetworkPartnerKycLimit]
  ) {
    self.partner = partner
    self.source = source
    self.destination = destination
    self.paymentMethods = paymentMethods
    self.kycLimits = kycLimits
  }
}

// MARK: - Country defaults

/// The default fiat currency and payment methods of a country for a category.
public struct MeldNetworkPartnerCountryDefaults: Codable, Equatable {
  public let countryCode: String
  public let category: MeldCategory
  public let currencyCode: String
  /// In the vocabulary of a quote's `paymentMethodType`, e.g. `CREDIT_DEBIT_CARD`.
  public let paymentMethods: [String]

  public init(countryCode: String, category: MeldCategory, currencyCode: String, paymentMethods: [String]) {
    self.countryCode = countryCode
    self.category = category
    self.currencyCode = currencyCode
    self.paymentMethods = paymentMethods
  }
}

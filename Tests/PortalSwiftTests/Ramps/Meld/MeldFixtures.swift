//
//  MeldFixtures.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation

/// Meld responses captured on 2026-11-13 against staging (`api.portalhq.dev`, Meld sandbox) for a
/// newly signed-up client, through connect-api's `/api/v3/clients/me/integrations/meld` proxy.
/// Each is the `data` Portal wraps in `{ "data": ... }`, except the `error*` ones, which are whole
/// error bodies. Lists are cut to their first items; names, emails, phone numbers, external ids,
/// tokens and Meld's customer and account ids are replaced with placeholders, which keeps every
/// field's type. The Android SDK's tests load the same files from `src/test/resources/meld/`.
///
/// `synthetic*` fixtures are hand-built from connect-api's `src/libs/meld/schemas.ts`: the sandbox
/// could not produce them (no widget session or purchase yet, an empty KYC-limit list, a customer
/// with every optional field). Replace them with real captures when they become available.
enum MeldFixtures {
  /// `customer-create.json` (captured)
  static let customerCreate = #"""
  {"id":"meld-customer-1","accountId":"meld-account-1","externalId":"REDACTED_externalId","name":{"firstName":"REDACTED_firstName","lastName":"REDACTED_lastName"},"dateOfBirth":null,"email":"REDACTED_email","phone":null,"emailVerifiedAt":null,"phoneVerifiedAt":null,"verificationMeta":null,"addresses":[],"serviceProviderCustomers":[],"previouslyUsedOnramps":[],"status":"ACTIVE","type":"INDIVIDUAL"}
  """#

  /// `customer-search-empty.json` (captured)
  static let customerSearchEmpty = #"""
  {"customers":[],"count":0,"remaining":0}
  """#

  /// `customer-search.json` (captured)
  static let customerSearch = #"""
  {"customers":[{"key":"REDACTED_key","id":"meld-customer-1","accountId":"meld-account-1","externalId":"REDACTED_externalId","name":{"firstName":"REDACTED_firstName","lastName":"REDACTED_lastName"},"dateOfBirth":null,"email":"REDACTED_email","phone":null,"emailVerifiedAt":null,"phoneVerifiedAt":null,"verificationMeta":null,"addresses":[],"serviceProviderCustomers":[],"previouslyUsedOnramps":[],"status":"ACTIVE","type":"INDIVIDUAL"}],"count":1,"remaining":0}
  """#

  /// `error-customer-duplicate.json` (captured, HTTP 409 body)
  static let errorCustomerDuplicate = #"""
  {"error":"Meld customer already exists for this client. Use GET /customers to retrieve it.","details":{"meldCustomerId":"meld-customer-1"}}
  """#

  /// `error-quote-missing-country.json` (captured, HTTP 400 body)
  static let errorQuoteMissingCountry = #"""
  {"error":"countryCode must be a string."}
  """#

  /// `error-quote-unsupported-pair.json` (captured, HTTP 400 body)
  static let errorQuoteUnsupportedPair = #"""
  {"error":"Meld API error: Invalid Parameters passed "}
  """#

  /// `error-transaction-invalid-id.json` (captured, HTTP 400 body)
  static let errorTransactionInvalidId = #"""
  {"error":"Meld API error: Not a valid id: does-not-exist"}
  """#

  /// `error-widget-client-ip-required.json` (captured, HTTP 400 body)
  static let errorWidgetClientIpRequired = #"""
  {"error":"Meld API error: clientIpAddress is required for the requested service provider"}
  """#

  /// `error-widget-unknown-provider.json` (captured, HTTP 400 body)
  static let errorWidgetUnknownProvider = #"""
  {"error":"Meld API error: Invalid JSON"}
  """#

  /// `np-countries.json` (captured)
  static let npCountries = #"""
  {"countries":[{"countryCode":"AD","name":"Andorra","flag":"https://cdn.meld.io/images-country/AD/flag.svg","subdivisions":[]},{"countryCode":"US","name":"United States","flag":"https://cdn.meld.io/images-country/US/flag.svg","subdivisions":[]}]}
  """#

  /// `np-currencies-crypto.json` (captured)
  static let npCurrenciesCrypto = #"""
  {"currencies":[{"currencyCode":"APT","name":"Aptos","decimalPlaces":18,"type":"CRYPTO","chainCode":"APTOS","symbol":"https://cdn.meld.io/images-currency/crypto/APT/symbol.png"},{"currencyCode":"ETH","name":"Ethereum","decimalPlaces":18,"type":"CRYPTO","chainCode":"ETH","chainId":"1","contract":"0x0000000000000000000000000000000000000000","symbol":"https://cdn.meld.io/images-currency/crypto/ETH/symbol.png"},{"currencyCode":"SOL","name":"Solana","decimalPlaces":18,"type":"CRYPTO","chainCode":"SOLANA","chainId":"101","contract":"So11111111111111111111111111111111111111111","symbol":"https://cdn.meld.io/images-currency/crypto/SOL/symbol.png"}]}
  """#

  /// `np-currencies-fiat.json` (captured)
  static let npCurrenciesFiat = #"""
  {"currencies":[{"currencyCode":"USD","name":"US Dollar","decimalPlaces":3,"type":"FIAT","symbol":"https://cdn.meld.io/images-currency/fiat/USD/symbol.png"}]}
  """#

  /// `np-defaults.json` (captured)
  static let npDefaults = #"""
  {"countryCode":"US","category":"CRYPTO_ONRAMP","currencyCode":"USD","paymentMethods":["CREDIT_DEBIT_CARD","APPLE_PAY","GOOGLE_PAY","FEDNOW"]}
  """#

  /// `np-fiat-limits.json` (captured)
  static let npFiatLimits = #"""
  {"fiatLimits":[{"provider":"TRANSAK","category":"CRYPTO_ONRAMP","countryCode":"US","currencyCode":"USD","paymentMethod":"APPLE_PAY","min":30,"max":1000},{"provider":"TRANSAK","category":"CRYPTO_ONRAMP","countryCode":"US","currencyCode":"USD","paymentMethod":"CREDIT_DEBIT_CARD","min":5,"max":3000}]}
  """#

  /// `np-kyc-limits-empty.json` (captured)
  static let npKycLimitsEmpty = #"""
  {"kycLimits":[]}
  """#

  /// `np-partners.json` (captured)
  static let npPartners = #"""
  [{"serviceProvider":"TRANSAK","name":"Transak","status":"LIVE","categories":["CRYPTO_OFFRAMP","CRYPTO_ONRAMP"],"capabilities":[{"category":"CRYPTO_OFFRAMP","domains":["PAYMENT"],"status":"LIVE"},{"category":"CRYPTO_ONRAMP","domains":["PAYMENT"],"status":"LIVE"}],"url":"https://transak.com","supportUrl":"https://support.transak.com","lastLoadedAt":"2026-11-10T17:14:10.915806Z","logo":{"dark":"https://cdn.meld.io/images-serviceprovider/TRANSAK/logo_dark.png","light":"https://cdn.meld.io/images-serviceprovider/TRANSAK/logo_light.png","darkShort":"https://cdn.meld.io/images-serviceprovider/TRANSAK/short_logo_dark.png","lightShort":"https://cdn.meld.io/images-serviceprovider/TRANSAK/short_logo_light.png"},"headless":{"supported":false,"uiCustomization":false},"checkout":true,"kycMode":"NONE","kycLevel":"LEVEL_2","kycShareMethods":[],"isExchange":false}]
  """#

  /// `np-payment-methods.json` (captured)
  static let npPaymentMethods = #"""
  [{"countryCode":"US","providerMethod":"apple_pay","method":"APPLE_PAY","category":"CRYPTO_ONRAMP","name":"Apple Pay","type":"MOBILE_WALLET","logo":{"dark":"https://cdn.meld.io/images-paymentmethod/APPLE_PAY/logo_dark.png","light":"https://cdn.meld.io/images-paymentmethod/APPLE_PAY/logo_light.png"},"headlessSupported":false,"checkoutSupported":true},{"countryCode":"US","providerMethod":"credit_debit_card","method":"CREDIT_DEBIT_CARD","category":"CRYPTO_ONRAMP","name":"Credit & Debit Card","type":"CARD","logo":{"dark":"https://cdn.meld.io/images-paymentmethod/CREDIT_DEBIT_CARD/logo_dark.png","light":"https://cdn.meld.io/images-paymentmethod/CREDIT_DEBIT_CARD/logo_light.png"},"headlessSupported":false,"checkoutSupported":true}]
  """#

  /// `np-routes.json` (captured)
  static let npRoutes = #"""
  [{"partner":"TRANSAK","source":"USD","destination":"ETH","paymentMethods":[{"paymentType":"MOBILE_WALLET","name":"APPLE_PAY","partnerMethodName":"apple_pay","category":"CRYPTO_ONRAMP","limits":{"currencyCode":"USD","min":30,"max":1000},"logo":{"dark":"https://cdn.meld.io/images-paymentmethod/APPLE_PAY/logo_dark.png","light":"https://cdn.meld.io/images-paymentmethod/APPLE_PAY/logo_light.png"},"headlessSupported":false,"checkoutSupported":true},{"paymentType":"CARD","name":"CREDIT_DEBIT_CARD","partnerMethodName":"credit_debit_card","category":"CRYPTO_ONRAMP","limits":{"currencyCode":"USD","min":5,"max":3000},"logo":{"dark":"https://cdn.meld.io/images-paymentmethod/CREDIT_DEBIT_CARD/logo_dark.png","light":"https://cdn.meld.io/images-paymentmethod/CREDIT_DEBIT_CARD/logo_light.png"},"headlessSupported":false,"checkoutSupported":true}],"kycLimits":[]}]
  """#

  /// `quote.json` (captured)
  static let quote = #"""
  {"quotes":[{"transactionType":"CRYPTO_PURCHASE","sourceAmount":100,"sourceAmountWithoutFees":94.01,"fiatAmountWithoutFees":94.01,"destinationAmountWithoutFees":null,"sourceCurrencyCode":"USD","countryCode":"US","totalFee":5.99,"networkFee":null,"partnerFee":1,"transactionFee":4.99,"destinationAmount":0.0461126,"destinationCurrencyCode":"ETH","exchangeRate":2168.6,"paymentMethodType":"CREDIT_DEBIT_CARD","serviceProvider":"TRANSAK","rampIntelligence":{"rampScore":90.54,"lowKyc":false,"previouslyUsed":null},"isNativeAvailable":null}],"message":null,"error":null,"timestamp":null}
  """#

  /// `synthetic-customer-full.json` (synthetic, from `schemas.ts`)
  static let syntheticCustomerFull = #"""
  {"id":"meld-customer-1","accountId":"meld-account-1","externalId":"REDACTED_externalId","key":"REDACTED_key","name":{"firstName":"REDACTED_firstName","lastName":null},"email":"REDACTED_email","phone":"REDACTED_phone","dateOfBirth":"1990-01-31","type":"INDIVIDUAL","status":"ACTIVE","addresses":[{"id":"address-1","customerId":"meld-customer-1","type":"RESIDENCE","status":"ACTIVE","addressDetails":{"lineOne":"1 Main St","lineTwo":null,"city":"Austin","region":"TX","postalCode":"78701","country":"US"}}],"emailVerifiedAt":"2026-11-12T10:00:00Z","phoneVerifiedAt":null,"verificationMeta":{"documentType":"PASSPORT","checks":{"liveness":true,"score":0.97,"notes":null},"tags":["manual",2]},"serviceProviders":{"TRANSAK":{"linked":true}},"previouslyUsedOnramps":[{"previouslyUsed":"2026-11-01T08:30:00Z","serviceProvider":"TRANSAK"}],"serviceProviderCustomers":[{"id":"spc-1","customerId":"meld-customer-1","serviceProvider":"TRANSAK","serviceProviderAccessProfileId":null,"serviceProviderDetails":{"partnerUserId":"abc","tier":2,"flags":[]},"status":"ACTIVE","wallets":["0x000000000000000000000000000000000000dEaD"],"kyc":{"additionalInfo":{"reason":null,"attempts":1},"onboardingMethod":{"kycProvider":"SUMSUB","onboardingType":"FULL"},"status":"APPROVED","updatedAt":"2026-11-02T09:00:00Z"},"createdAt":"2026-11-01T08:00:00Z","deletedAt":null}]}
  """#

  /// `synthetic-np-kyc-limits.json` (synthetic, from `schemas.ts`)
  static let syntheticNpKycLimits = #"""
  {"kycLimits":[{"provider":"TRANSAK","category":"CRYPTO_ONRAMP","countryCode":"US","limitType":"DAILY","currencyCode":"USD","level1":1000,"level2":5000,"level3":25000}]}
  """#

  /// `synthetic-quote-empty.json` (synthetic, from `schemas.ts`)
  static let syntheticQuoteEmpty = #"""
  {"quotes":[],"message":"No quotes available for this request","error":"NO_QUOTES","timestamp":"2026-11-13T09:00:00Z"}
  """#

  /// `synthetic-transaction.json` (synthetic, from `schemas.ts`)
  static let syntheticTransaction = #"""
  {"transaction":{"id":"WQ5Xa8b9Yx2nZdF3kJ7mPq","sessionId":"WePmn7gkbbsaRY3vHnNkdF","externalSessionId":null,"externalCustomerId":"REDACTED_externalCustomerId","customerId":"meld-customer-1","customer":{"externalId":"REDACTED_externalId"},"status":"SETTLED","transactionType":"CRYPTO_PURCHASE","serviceProvider":"TRANSAK","sourceAmount":100,"sourceCurrencyCode":"USD","destinationAmount":0.0461126,"destinationCurrencyCode":"ETH","createdAt":"2026-11-13T09:00:00.000Z","updatedAt":"2026-11-13T09:05:00.000Z","paymentMethodType":"CREDIT_DEBIT_CARD","cryptoDetails":{"blockchainTransactionId":"0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060","chainId":"1","destinationWalletAddress":"0x000000000000000000000000000000000000dEaD","sourceWalletAddress":null,"sessionWalletAddress":null,"institution":null,"networkFee":0.5,"partnerFee":1,"swapFee":null,"totalFee":5.99,"transactionFee":4.99},"serviceProviderDetails":{"orderId":"transak-order-1","fees":{"network":0.5,"partner":null}},"fiatAmountInUsd":100}}
  """#

  /// `synthetic-transactions-search.json` (synthetic, from `schemas.ts`)
  static let syntheticTransactionsSearch = #"""
  {"count":1,"remaining":0,"totalCount":1,"transactions":[{"id":"WQ5Xa8b9Yx2nZdF3kJ7mPq","sessionId":"WePmn7gkbbsaRY3vHnNkdF","externalSessionId":null,"externalCustomerId":"REDACTED_externalCustomerId","customerId":"meld-customer-1","customer":{"externalId":"REDACTED_externalId"},"status":"SETTLED","transactionType":"CRYPTO_PURCHASE","serviceProvider":"TRANSAK","sourceAmount":100,"sourceCurrencyCode":"USD","destinationAmount":0.0461126,"destinationCurrencyCode":"ETH","createdAt":"2026-11-13T09:00:00.000Z","updatedAt":"2026-11-13T09:05:00.000Z","paymentMethodType":"CREDIT_DEBIT_CARD","cryptoDetails":{"blockchainTransactionId":"0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060","chainId":"1","destinationWalletAddress":"0x000000000000000000000000000000000000dEaD","sourceWalletAddress":null,"sessionWalletAddress":null,"institution":null,"networkFee":0.5,"partnerFee":1,"swapFee":null,"totalFee":5.99,"transactionFee":4.99},"serviceProviderDetails":{"orderId":"transak-order-1","fees":{"network":0.5,"partner":null}},"fiatAmountInUsd":100}]}
  """#

  /// `synthetic-widget-session.json` (synthetic, from `schemas.ts`)
  static let syntheticWidgetSession = #"""
  {"id":"WePmn7gkbbsaRY3vHnNkdF","token":"REDACTED_token","customerId":"meld-customer-1","externalCustomerId":"REDACTED_externalCustomerId","externalSessionId":null,"widgetUrl":"https://meldcrypto.com/?token=REDACTED","serviceProviderWidgetUrl":null}
  """#

  /// `transactions-search-empty.json` (captured)
  static let transactionsSearchEmpty = #"""
  {"transactions":[],"count":0,"remaining":0,"totalCount":0}
  """#
}

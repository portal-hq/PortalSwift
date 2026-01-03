//
//  PortalSwaps.swift
//  PortalSwift
//

import AnyCodable
import Foundation

public struct Quote: Codable, Equatable {
  public var allowanceTarget: String
  public var cost: Double
  public var transaction: ETHTransactionParam
}

public struct QuoteArgs: Codable {
  // Required
  public var buyToken: String
  public var sellToken: String

  // One of these two is required
  public var sellAmount: String?
  public var buyAmount: String?

  // Optional
  public var affiliateAddress: String?
  public var buyTokenPercentageFee: Double?
  public var enableSlippageProtection: Bool?
  public var excludedSources: String?
  public var feeRecipient: String?
  public var gasPrice: Double?
  public var includedSources: String?
  public var intentOnFilling: Bool?
  public var priceImpactProtectionPercentage: Double?
  public var skipValidation: Bool?
  public var slippagePercentage: Double?
  public var takerAddress: String?

  public init(buyToken: String, sellToken: String, buyAmount: String) {
    self.buyToken = buyToken
    self.sellToken = sellToken
    self.buyAmount = buyAmount
  }

  public init(buyToken: String, sellToken: String, sellAmount: String) {
    self.buyToken = buyToken
    self.sellToken = sellToken
    self.sellAmount = sellAmount
  }

  public func toDictionary() -> [String: AnyCodable] {
    var dictionary: [String: AnyCodable] = [
      // Always required
      "buyToken": AnyCodable(buyToken),
      "sellToken": AnyCodable(sellToken)
    ]

    // Either buyAmount or sellAmount MUST be set for the quote to return a usable value
    if self.buyAmount != nil {
      dictionary["buyAmount"] = AnyCodable(self.buyAmount)
    }

    if self.sellAmount != nil {
      dictionary["sellAmount"] = AnyCodable(self.sellAmount)
    }

    // The rest of these are truly optional
    if self.affiliateAddress != nil {
      dictionary["affiliateAddress"] = AnyCodable(self.affiliateAddress)
    }
    if self.buyTokenPercentageFee != nil {
      dictionary["buyTokenPercentageFee"] = AnyCodable(self.buyTokenPercentageFee)
    }
    if self.enableSlippageProtection != nil {
      dictionary["enableSlippageProtection"] = AnyCodable(self.enableSlippageProtection)
    }
    if self.excludedSources != nil {
      dictionary["excludedSources"] = AnyCodable(self.excludedSources)
    }
    if self.feeRecipient != nil {
      dictionary["feeRecipient"] = AnyCodable(self.feeRecipient)
    }
    if self.gasPrice != nil {
      dictionary["gasPrice"] = AnyCodable(self.gasPrice)
    }
    if self.includedSources != nil {
      dictionary["includedSources"] = AnyCodable(self.includedSources)
    }
    if self.intentOnFilling != nil {
      dictionary["intentOnFilling"] = AnyCodable(self.intentOnFilling)
    }
    if self.priceImpactProtectionPercentage != nil {
      dictionary["priceImpactProtectionPercentage"] = AnyCodable(self.priceImpactProtectionPercentage)
    }
    if self.skipValidation != nil {
      dictionary["skipValidation"] = AnyCodable(self.skipValidation)
    }
    if self.slippagePercentage != nil {
      dictionary["slippagePercentage"] = AnyCodable(self.slippagePercentage)
    }
    if self.takerAddress != nil {
      dictionary["takerAddress"] = AnyCodable(self.takerAddress)
    }

    return dictionary
  }
}

@available(*, deprecated, message: "PortalSwapsProtocol has been replaced by ZeroX trading. Please use 'portal.trading.zeroX' instead.")
public protocol PortalSwapsProtocol {
  @available(*, deprecated, message: "This method has been replaced by ZeroX trading. Please use 'portal.trading.zeroX.getQuote()' instead.")
  func getQuote(args: QuoteArgs, forChainId: String?) async throws -> Quote

  @available(*, deprecated, message: "This method has been replaced by ZeroX trading. Please use 'portal.trading.zeroX.getSources()' instead.")
  func getSources(forChainId: String) async throws -> [String: String]
}

@available(*, deprecated, message: "PortalSwaps has been replaced by ZeroX trading. Please use 'portal.trading.zeroX' instead.")
public class PortalSwaps: PortalSwapsProtocol {
  private var apiKey: String
  private var portal: PortalProtocol

  public init(apiKey: String, portal: PortalProtocol) {
    self.apiKey = apiKey
    self.portal = portal
  }

  @available(*, deprecated, message: "This method has been replaced by ZeroX trading. Please use 'portal.trading.zeroX.getQuote()' instead.")
  public func getQuote(args: QuoteArgs, forChainId: String? = nil) async throws -> Quote {
    return try await self.portal.api.getQuote(self.apiKey, withArgs: args, forChainId: forChainId)
  }

  @available(*, deprecated, message: "This method has been replaced by ZeroX trading. Please use 'portal.trading.zeroX.getSources()' instead.")
  public func getSources(forChainId: String) async throws -> [String: String] {
    return try await self.portal.api.getSources(self.apiKey, forChainId: forChainId)
  }

  // MARK: - Deprecated functions

  @available(*, deprecated, renamed: "getQuote", message: "Please use the async/await implementation of getQuote().")
  public func getQuote(args: QuoteArgs, forChainId: String, completion: @escaping (Result<Quote>) -> Void) {
    do {
      try self.portal.api.getQuote(self.apiKey, args, forChainId) { result in
        completion(result)
      }
    } catch {
      completion(Result(error: error))
    }
  }

  @available(*, deprecated, renamed: "getQuote", message: "Please use the async/await implementation of getQuote().")
  public func getQuote(args: QuoteArgs, completion: @escaping (Result<Quote>) -> Void) {
    do {
      try self.portal.api.getQuote(self.apiKey, args, nil) { result in
        completion(result)
      }
    } catch {
      completion(Result(error: error))
    }
  }

  @available(*, deprecated, renamed: "getSources", message: "Please use the async/await implementation of getSources().")
  public func getSources(completion: @escaping (Result<[String: String]>) -> Void) {
    do {
      try self.portal.api.getSources(swapsApiKey: self.apiKey) { result in
        completion(result)
      }
    } catch {
      completion(Result(error: error))
    }
  }
}

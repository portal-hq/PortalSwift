//
//  PortalSwaps.swift
//  PortalSwift
//
//  Created by Blake Williams on 5/8/23.
//

import Foundation

public struct Quote: Codable {
  var cost: Double
  var transaction: ETHTransactionParam
}

public struct QuoteArgs: Codable {
  // Required
  var buyToken: String
  var sellToken: String

  // One of these two is required
  var sellAmount: Double?
  var buyAmount: Double?

  // Optional
  var affiliateAddress: String?
  var buyTokenPercentageFee: Double?
  var enableSlippageProtection: Bool?
  var excludedSources: String?
  var feeRecipient: String?
  var gasPrice: Double?
  var includedSources: String?
  var intentOnFilling: Bool?
  var priceImpactProtectionPercentage: Double?
  var skipValidation: Bool?
  var slippagePercentage: Double?
  var takerAddress: String?

  init(buyToken: String, sellToken: String, buyAmount: Double) {
    self.buyToken = buyToken
    self.sellToken = sellToken
    self.buyAmount = buyAmount
  }

  init(buyToken: String, sellToken: String, sellAmount: Double) {
    self.buyToken = buyToken
    self.sellToken = sellToken
    self.sellAmount = sellAmount
  }

  public func toDictionary() -> [String: Any] {
    var dictionary: [String: Any] = [
      // Always required
      "buyToken": buyToken,
      "sellToken": sellToken,
    ]

    // Either buyAmount or sellAmount MUST be set for the quote to return a usable value
    if buyAmount != nil {
      dictionary["buyAmount"] = buyAmount
    }

    if sellAmount != nil {
      dictionary["sellAmount"] = sellAmount
    }

    // The rest of these are truly optional
    if affiliateAddress != nil {
      dictionary["affiliateAddress"] = affiliateAddress
    }
    if buyTokenPercentageFee != nil {
      dictionary["buyTokenPercentageFee"] = buyTokenPercentageFee
    }
    if enableSlippageProtection != nil {
      dictionary["enableSlippageProtection"] = enableSlippageProtection
    }
    if excludedSources != nil {
      dictionary["excludedSources"] = excludedSources
    }
    if feeRecipient != nil {
      dictionary["feeRecipient"] = feeRecipient
    }
    if gasPrice != nil {
      dictionary["gasPrice"] = gasPrice
    }
    if includedSources != nil {
      dictionary["includedSources"] = includedSources
    }
    if intentOnFilling != nil {
      dictionary["intentOnFilling"] = intentOnFilling
    }
    if priceImpactProtectionPercentage != nil {
      dictionary["priceImpactProtectionPercentage"] = priceImpactProtectionPercentage
    }
    if skipValidation != nil {
      dictionary["skipValidation"] = skipValidation
    }
    if slippagePercentage != nil {
      dictionary["slippagePercentage"] = slippagePercentage
    }
    if takerAddress != nil {
      dictionary["takerAddress"] = takerAddress
    }

    return dictionary
  }
}

public class PortalSwaps {
  private var apiKey: String
  private var portal: Portal

  init(apiKey: String, portal: Portal) {
    self.apiKey = apiKey
    self.portal = portal
  }

  public func getQuote(args: QuoteArgs, completion: @escaping (Result<Quote>) -> Void) {
    do {
      try portal.api.getQuote(apiKey, args) { result in
        completion(result)
      }
    } catch {
      completion(Result(error: error))
    }
  }

  public func getSources(completion: @escaping (Result<[String: String]>) -> Void) {
    do {
      try portal.api.getSources(swapsApiKey: apiKey) { result in
        completion(result)
      }
    } catch {
      completion(Result(error: error))
    }
  }
}

//
//  PortalSwaps.swift
//  PortalSwift
//
//  Created by Blake Williams on 5/8/23.
//

import Foundation

struct Quote {
  var cost: Double
  var transaction: ETHTransactionParam
}

struct QuoteArgs: Codable {
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
  
  init (buyToken: String, sellToken: String, buyAmount: Double) {
    self.buyToken = buyToken
    self.sellToken = sellToken
    self.buyAmount = buyAmount
  }
  
  init (buyToken: String, sellToken: String, sellAmount: Double) {
    self.buyToken = buyToken
    self.sellToken = sellToken
    self.sellAmount = sellAmount
  }
}

struct QuoteOrder: Codable {
  var makerToken: String
  var takerToken: String
  var makerAmount: String
  var takerAmount: String
  var fillData: QuoteOrderFillData
  var source: String
  var sourcePathId: String
  var type: Int
}

struct QuoteOrderFillData: Codable {
  var tokenAddressPath: [String]
  var router: String
}

struct QuoteResponse: Codable {
  var allowanceTarget: String
  var buyAmount: String
  var buyTokenAddress: String
  var buyTokenToEthRate: String
  var chainId: String
  var data: String
  var estimatedGas: String
  var estimatedPriceImpact: String
  var gas: String
  var gasPrice: String
  var guaranteedPrice: String
  var minimumProtocolFee: String
  var orders: [QuoteOrder]
  var price: String
  var protocolFee: String
  var sellAmount: String
  var sellTokenAddress: String
  var sellTokenToEthRate: String
  var sources: [QuoteSource]
  var to: String
  var value: String
}

struct QuoteSource: Codable {
  var name: String
  var proportion: String
}

struct SourcesResponse: Codable {
  var records: [String]
}

class PortalSwaps {
  private var portal: Portal
  private var domain: String = "api.0x.org"
  
  init(portal: Portal) {
    self.portal = portal
  }
  
  public func execute(
    payload: ETHTransactionPayload,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) {
      portal.provider.request(payload: payload) { result in
        if (result.error != nil) {
          completion(Result(error: result.error!))
        }
        
        completion(Result(data: result.data!))
      }
  }
  
  public func getQuote(args: [String:Any], completion: @escaping (Result<Quote>) -> Void) {
    do {
      let address = try portal.keychain.getAddress()
      
      let host = buildHostForChain()
      let qs = try serializeObject(args)
      let request = HttpRequest<QuoteResponse, [String:String]>(
        url: "https://\(host)/swap/v1/quote?\(qs)",
        method: "GET",
        body: [:],
        headers: [:],
        requestType: HttpRequestType.CustomRequest
      )
      
      request.send() { result in
        if (result.error != nil) {
          return completion(Result(error: result.error!))
        }
        
        let response = result.data!
        
        let transaction = ETHTransactionParam(
          from: address,
          to: response.to,
          gas: EthRequestUtils.numberToHexString(number: Double(response.gas)!), // Convert to hex
          gasPrice: EthRequestUtils.numberToHexString(number: Double(response.gasPrice)!), // Convert to hex
          value: EthRequestUtils.numberToHexString(number: Double(response.value)!), // Convert to hex
          data: response.data
        )
        
        let quote = Quote(
          cost: Double(response.guaranteedPrice)!,
          transaction: transaction
        )
        
        completion(Result(data: quote))
      }
    } catch {
      completion(Result(error: error))
    }
  }
  
  public func getSources(completion: @escaping(Result<[String]>) -> Void) -> Void {
    let host = buildHostForChain()
    
    let request = HttpRequest<SourcesResponse, [String:Any]>(
      url: "https://\(host)/swap/v1/sources",
      method: "GET",
      body: [:],
      headers: [:],
      requestType: HttpRequestType.CustomRequest
    )
    
    request.send() { result in
      if (result.error != nil) {
        return completion(Result(error: result.error!))
      }
      
      let response = result.data!
      
      completion(Result(data: response.records))
    }
  }
  
  private func buildHostForChain() -> String {
    let chain = ChainUtils.getChainNameForId(portal.chainId)
    
    if (chain != nil) {
      return "\(chain!).\(domain)"
    }
    
    return domain
  }
  
  private func serializeObject(_ args: [String: Any]) throws -> String {
    do {
      let address = try portal.keychain.getAddress()
      
      var pairs: [String] = []
      
      for (key, value) in args {
        pairs.append("\(key)=\(value)")
      }
      
      pairs.append("affiliateAddress=\(address)")
      
      return pairs.joined(separator: "&")
    } catch {
      throw error
    }
  }
}

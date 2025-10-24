//
//  EnterYieldXyzRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to enter a yield opportunity
public struct EnterYieldXyzRequest: Codable {
    public let yieldId: String
    public let address: String
    public let arguments: EnterYieldArguments?
    
    public init(yieldId: String, address: String, arguments: EnterYieldArguments? = nil) {
        self.yieldId = yieldId
        self.address = address
        self.arguments = arguments
    }
}

/// Arguments for entering a yield opportunity
public struct EnterYieldArguments: Codable {
    public let amount: String?
    public let validatorAddress: String?
    public let validatorAddresses: [String]?
    public let providerId: String?
    public let duration: Int?
    public let inputToken: String?
    public let subnetId: Int?
    public let tronResource: TronResource?
    public let feeConfigurationId: String?
    public let cosmosPubKey: String?
    public let tezosPubKey: String?
    public let cAddressBech: String?
    public let pAddressBech: String?
    public let executionMode: ExecutionMode?
    public let ledgerWalletApiCompatible: Bool?
    
    public init(
        amount: String? = nil,
        validatorAddress: String? = nil,
        validatorAddresses: [String]? = nil,
        providerId: String? = nil,
        duration: Int? = nil,
        inputToken: String? = nil,
        subnetId: Int? = nil,
        tronResource: TronResource? = nil,
        feeConfigurationId: String? = nil,
        cosmosPubKey: String? = nil,
        tezosPubKey: String? = nil,
        cAddressBech: String? = nil,
        pAddressBech: String? = nil,
        executionMode: ExecutionMode? = nil,
        ledgerWalletApiCompatible: Bool? = nil
    ) {
        self.amount = amount
        self.validatorAddress = validatorAddress
        self.validatorAddresses = validatorAddresses
        self.providerId = providerId
        self.duration = duration
        self.inputToken = inputToken
        self.subnetId = subnetId
        self.tronResource = tronResource
        self.feeConfigurationId = feeConfigurationId
        self.cosmosPubKey = cosmosPubKey
        self.tezosPubKey = tezosPubKey
        self.cAddressBech = cAddressBech
        self.pAddressBech = pAddressBech
        self.executionMode = executionMode
        self.ledgerWalletApiCompatible = ledgerWalletApiCompatible
    }
}

/// Tron resource types
public enum TronResource: String, Codable {
    case BANDWIDTH
    case ENERGY
}

/// Execution modes for yield actions
public enum ExecutionMode: String, Codable {
    case individual
    case batch
}


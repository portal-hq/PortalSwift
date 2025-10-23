//
//  GetYieldsResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation
import AnyCodable

/// Response containing yield opportunities from Yield.xyz
public struct GetYieldsResponse: Codable {
    public let data: GetYieldsData
    
    public init(data: GetYieldsData) {
        self.data = data
    }
}

public struct GetYieldsData: Codable {
    public let rawResponse: GetYieldsRawResponse
    
    public init(rawResponse: GetYieldsRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct GetYieldsRawResponse: Codable {
    public let items: [YieldOpportunity]
    public let limit: Int
    public let offset: Int
    public let total: Int
    
    public init(items: [YieldOpportunity], limit: Int, offset: Int, total: Int) {
        self.items = items
        self.limit = limit
        self.offset = offset
        self.total = total
    }
}

/// A yield opportunity
public struct YieldOpportunity: Codable {
    public let id: String
    public let network: String
    public let inputTokens: [YieldXyzToken]
    public let outputToken: YieldXyzToken
    public let token: YieldXyzToken
    public let rewardRate: YieldXyzRewardRate
    public let statistics: YieldXyzStatistics?
    public let status: YieldXyzStatus
    public let metadata: YieldXyzMetadata
    public let mechanics: YieldXyzMechanics
    public let providerId: String
    public let tags: [String]
    
    public init(
        id: String,
        network: String,
        inputTokens: [YieldXyzToken],
        outputToken: YieldXyzToken,
        token: YieldXyzToken,
        rewardRate: YieldXyzRewardRate,
        statistics: YieldXyzStatistics? = nil,
        status: YieldXyzStatus,
        metadata: YieldXyzMetadata,
        mechanics: YieldXyzMechanics,
        providerId: String,
        tags: [String]
    ) {
        self.id = id
        self.network = network
        self.inputTokens = inputTokens
        self.outputToken = outputToken
        self.token = token
        self.rewardRate = rewardRate
        self.statistics = statistics
        self.status = status
        self.metadata = metadata
        self.mechanics = mechanics
        self.providerId = providerId
        self.tags = tags
    }
}

/// Token information
public struct YieldXyzToken: Codable {
    public let symbol: String
    public let name: String
    public let decimals: Int?
    public let network: String?
    public let address: String?
    public let logoURI: String?
    public let isPoints: Bool?
    public let coinGeckoId: String?
    
    public init(
        symbol: String,
        name: String,
        decimals: Int? = nil,
        network: String? = nil,
        address: String? = nil,
        logoURI: String? = nil,
        isPoints: Bool? = nil,
        coinGeckoId: String? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
        self.network = network
        self.address = address
        self.logoURI = logoURI
        self.isPoints = isPoints
        self.coinGeckoId = coinGeckoId
    }
}

/// Reward rate information
public struct YieldXyzRewardRate: Codable {
    public let total: Double
    public let rateType: RateType
    public let components: [YieldXyzRewardRateComponent]
    
    public init(total: Double, rateType: RateType, components: [YieldXyzRewardRateComponent]) {
        self.total = total
        self.rateType = rateType
        self.components = components
    }
}

/// Rate type enum
public enum RateType: String, Codable {
    case APR
    case APY
}

/// Reward rate component
public struct YieldXyzRewardRateComponent: Codable {
    public let rate: Double
    public let rateType: RateType
    public let token: YieldXyzToken
    public let yieldSource: YieldSource
    public let description: String
    
    public init(
        rate: Double,
        rateType: RateType,
        token: YieldXyzToken,
        yieldSource: YieldSource,
        description: String
    ) {
        self.rate = rate
        self.rateType = rateType
        self.token = token
        self.yieldSource = yieldSource
        self.description = description
    }
}

/// Yield source enum
public enum YieldSource: String, Codable {
    case staking
    case restaking
    case protocol_incentive
    case points
    case lending_interest
    case mev
    case real_world_asset_yield
    case validator_commission
}

/// Statistics for a yield opportunity
public struct YieldXyzStatistics: Codable {
    public let tvlUsd: String?
    public let tvl: Double?
    public let uniqueUsers: Int?
    public let averagePositionSizeUsd: Double?
    public let averagePositionSize: Double?
    
    public init(
        tvlUsd: String? = nil,
        tvl: Double? = nil,
        uniqueUsers: Int? = nil,
        averagePositionSizeUsd: Double? = nil,
        averagePositionSize: Double? = nil
    ) {
        self.tvlUsd = tvlUsd
        self.tvl = tvl
        self.uniqueUsers = uniqueUsers
        self.averagePositionSizeUsd = averagePositionSizeUsd
        self.averagePositionSize = averagePositionSize
    }
}

/// Status of a yield opportunity
public struct YieldXyzStatus: Codable {
    public let enter: Bool
    public let exit: Bool
    
    public init(enter: Bool, exit: Bool) {
        self.enter = enter
        self.exit = exit
    }
}

/// Metadata for a yield opportunity
public struct YieldXyzMetadata: Codable {
    public let name: String
    public let logoURI: String
    public let description: String
    public let documentation: String
    public let underMaintenance: Bool
    public let deprecated: Bool
    public let supportedStandards: [String]
    
    public init(
        name: String,
        logoURI: String,
        description: String,
        documentation: String,
        underMaintenance: Bool,
        deprecated: Bool,
        supportedStandards: [String]
    ) {
        self.name = name
        self.logoURI = logoURI
        self.description = description
        self.documentation = documentation
        self.underMaintenance = underMaintenance
        self.deprecated = deprecated
        self.supportedStandards = supportedStandards
    }
}

/// Mechanics information for a yield opportunity
public struct YieldXyzMechanics: Codable {
    public let type: YieldXyzMechanicsType
    public let requiresValidatorSelection: Bool
    public let rewardSchedule: YieldXyzRewardSchedule
    public let rewardClaiming: YieldXyzRewardClaiming
    public let gasFeeToken: YieldXyzToken
    public let lockupPeriod: YieldXyzLockupPeriod?
    public let cooldownPeriod: YieldXyzCooldownPeriod?
    public let warmupPeriod: YieldXyzWarmupPeriod?
    public let fee: YieldXyzFee?
    public let entryLimits: YieldXyzEntryLimits
    public let supportsLedgerWalletApi: Bool
    public let extraTransactionFormatsSupported: [String]?
    public let arguments: YieldXyzArguments
    public let possibleFeeTakingMechanisms: YieldXyzPossibleFeeTakingMechanisms
    
    public init(
        type: YieldXyzMechanicsType,
        requiresValidatorSelection: Bool,
        rewardSchedule: YieldXyzRewardSchedule,
        rewardClaiming: YieldXyzRewardClaiming,
        gasFeeToken: YieldXyzToken,
        lockupPeriod: YieldXyzLockupPeriod? = nil,
        cooldownPeriod: YieldXyzCooldownPeriod? = nil,
        warmupPeriod: YieldXyzWarmupPeriod? = nil,
        fee: YieldXyzFee? = nil,
        entryLimits: YieldXyzEntryLimits,
        supportsLedgerWalletApi: Bool,
        extraTransactionFormatsSupported: [String]? = nil,
        arguments: YieldXyzArguments,
        possibleFeeTakingMechanisms: YieldXyzPossibleFeeTakingMechanisms
    ) {
        self.type = type
        self.requiresValidatorSelection = requiresValidatorSelection
        self.rewardSchedule = rewardSchedule
        self.rewardClaiming = rewardClaiming
        self.gasFeeToken = gasFeeToken
        self.lockupPeriod = lockupPeriod
        self.cooldownPeriod = cooldownPeriod
        self.warmupPeriod = warmupPeriod
        self.fee = fee
        self.entryLimits = entryLimits
        self.supportsLedgerWalletApi = supportsLedgerWalletApi
        self.extraTransactionFormatsSupported = extraTransactionFormatsSupported
        self.arguments = arguments
        self.possibleFeeTakingMechanisms = possibleFeeTakingMechanisms
    }
}

/// Reward schedule enum
public enum YieldXyzRewardSchedule: String, Codable {
    case block
    case hour
    case day
    case week
    case month
    case era
    case epoch
    case campaign
}

/// Reward claiming enum
public enum YieldXyzRewardClaiming: String, Codable {
    case auto
    case manual
}

/// Lockup period information
public struct YieldXyzLockupPeriod: Codable {
    public let seconds: Int64
    
    public init(seconds: Int64) {
        self.seconds = seconds
    }
}

/// Cooldown period information
public struct YieldXyzCooldownPeriod: Codable {
    public let seconds: Int64
    
    public init(seconds: Int64) {
        self.seconds = seconds
    }
}

/// Warmup period information
public struct YieldXyzWarmupPeriod: Codable {
    public let seconds: Int64
    
    public init(seconds: Int64) {
        self.seconds = seconds
    }
}

/// Fee information
public struct YieldXyzFee: Codable {
    public let deposit: Double
    public let withdrawal: Double
    public let performance: Double
    public let management: Double
    
    public init(deposit: Double, withdrawal: Double, performance: Double, management: Double) {
        self.deposit = deposit
        self.withdrawal = withdrawal
        self.performance = performance
        self.management = management
    }
}

/// Entry limits information
public struct YieldXyzEntryLimits: Codable {
    public let minimum: String?
    public let maximum: String?
    
    public init(minimum: String? = nil, maximum: String? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

/// Arguments for yield operations
public struct YieldXyzArguments: Codable {
    public let enter: YieldXyzArgument
    public let exit: YieldXyzArgument
    public let manage: [String: AnyCodable]?
    public let balance: YieldXyzArgument?
    
    public init(
        enter: YieldXyzArgument,
        exit: YieldXyzArgument,
        manage: [String: AnyCodable]? = nil,
        balance: YieldXyzArgument? = nil
    ) {
        self.enter = enter
        self.exit = exit
        self.manage = manage
        self.balance = balance
    }
}

/// Argument definition
public struct YieldXyzArgument: Codable {
    public let fields: [YieldXyzArgumentField]
    public let notes: String?
    
    public init(fields: [YieldXyzArgumentField], notes: String? = nil) {
        self.fields = fields
        self.notes = notes
    }
}

/// Argument field definition
public struct YieldXyzArgumentField: Codable {
    public let name: YieldXyzArgumentFieldName
    public let type: YieldXyzArgumentFieldType
    public let label: String
    public let description: String?
    public let required: Bool?
    public let options: [String]?
    public let optionsRef: String?
    public let `default`: [String: AnyCodable]?
    public let placeholder: String?
    public let minimum: String?
    public let maximum: String?
    public let isArray: Bool?
    
    public init(
        name: YieldXyzArgumentFieldName,
        type: YieldXyzArgumentFieldType,
        label: String,
        description: String? = nil,
        required: Bool? = nil,
        options: [String]? = nil,
        optionsRef: String? = nil,
        default: [String: AnyCodable]? = nil,
        placeholder: String? = nil,
        minimum: String? = nil,
        maximum: String? = nil,
        isArray: Bool? = nil
    ) {
        self.name = name
        self.type = type
        self.label = label
        self.description = description
        self.required = required
        self.options = options
        self.optionsRef = optionsRef
        self.default = `default`
        self.placeholder = placeholder
        self.minimum = minimum
        self.maximum = maximum
        self.isArray = isArray
    }
}

/// Argument field name enum
public enum YieldXyzArgumentFieldName: String, Codable {
    case amount
    case validatorAddress
    case validatorAddresses
    case receiverAddress
    case providerId
    case duration
    case inputToken
    case subnetId
    case tronResource
    case feeConfigurationId
    case cosmosPubKey
    case tezosPubKey
    case cAddressBech
    case pAddressBech
    case executionMode
    case ledgerWalletApiCompatible
}

/// Argument field type enum
public enum YieldXyzArgumentFieldType: String, Codable {
    case string
    case number
    case address
    case `enum`
    case boolean
}

/// Possible fee taking mechanisms
public struct YieldXyzPossibleFeeTakingMechanisms: Codable {
    public let depositFee: Bool
    public let managementFee: Bool
    public let performanceFee: Bool
    public let validatorRebates: Bool
    
    public init(
        depositFee: Bool,
        managementFee: Bool,
        performanceFee: Bool,
        validatorRebates: Bool
    ) {
        self.depositFee = depositFee
        self.managementFee = managementFee
        self.performanceFee = performanceFee
        self.validatorRebates = validatorRebates
    }
}


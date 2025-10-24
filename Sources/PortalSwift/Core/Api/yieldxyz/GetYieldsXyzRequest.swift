//
//  GetYieldsXyzRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request parameters for getting yield opportunities from Yield.xyz
public struct GetYieldsXyzRequest: Codable {
    public let offset: Int?
    public let yieldId: String?
    public let network: String?
    public let limit: Int?
    public let type: YieldXyzMechanicsType?
    public let hasCooldownPeriod: Bool?
    public let hasWarmupPeriod: Bool?
    public let token: String?
    public let inputToken: String?
    public let provider: String?
    public let search: String?
    public let sort: YieldXyzSort?
    
    public init(
        offset: Int? = nil,
        yieldId: String? = nil,
        network: String? = nil,
        limit: Int? = nil,
        type: YieldXyzMechanicsType? = nil,
        hasCooldownPeriod: Bool? = nil,
        hasWarmupPeriod: Bool? = nil,
        token: String? = nil,
        inputToken: String? = nil,
        provider: String? = nil,
        search: String? = nil,
        sort: YieldXyzSort? = nil
    ) {
        self.offset = offset
        self.limit = limit
        self.network = network
        self.yieldId = yieldId
        self.type = type
        self.hasCooldownPeriod = hasCooldownPeriod
        self.hasWarmupPeriod = hasWarmupPeriod
        self.token = token
        self.inputToken = inputToken
        self.provider = provider
        self.search = search
        self.sort = sort
    }
}

/// Sort options for yield opportunities
public enum YieldXyzSort: String, Codable {
    case statusEnterAsc
    case statusEnterDesc
    case statusExitAsc
    case statusExitDesc
}

/// Yield mechanics types
public enum YieldXyzMechanicsType: String, Codable {
    case staking
    case restaking
    case lending
    case vault
    case fixed_yield
    case real_world_asset
}


//
//  MeldCustomerTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// A customer's name. Used in `MeldCreateCustomerRequest` and on `MeldCustomer`.
public struct MeldCustomerName: Codable, Equatable {
  public let firstName: String?
  public let lastName: String?

  public init(firstName: String? = nil, lastName: String? = nil) {
    self.firstName = firstName
    self.lastName = lastName
  }
}

/// The Meld customer of the current client.
public struct MeldCustomer: Codable, Equatable {
  public let id: String
  public let accountId: String
  /// Set by Portal from the client; never sent by the SDK.
  public let externalId: String
  /// Returned by `searchCustomer`; absent from the `createCustomer` response.
  public let key: String?
  public let name: MeldCustomerName?
  public let email: String?
  public let phone: String?
  public let dateOfBirth: String?
  public let type: MeldCustomerType?
  public let status: MeldCustomerStatus?
  public let addresses: [MeldCustomerAddress]?
  public let emailVerifiedAt: String?
  public let phoneVerifiedAt: String?
  /// Provider-specific verification data, passed through as Meld returns it.
  public let verificationMeta: [String: AnyCodable]?
  /// Provider-specific data, passed through as Meld returns it.
  public let serviceProviders: [String: AnyCodable]?
  public let previouslyUsedOnramps: [MeldPreviouslyUsedOnramp]?
  public let serviceProviderCustomers: [MeldServiceProviderCustomer]?

  public init(
    id: String,
    accountId: String,
    externalId: String,
    key: String? = nil,
    name: MeldCustomerName? = nil,
    email: String? = nil,
    phone: String? = nil,
    dateOfBirth: String? = nil,
    type: MeldCustomerType? = nil,
    status: MeldCustomerStatus? = nil,
    addresses: [MeldCustomerAddress]? = nil,
    emailVerifiedAt: String? = nil,
    phoneVerifiedAt: String? = nil,
    verificationMeta: [String: AnyCodable]? = nil,
    serviceProviders: [String: AnyCodable]? = nil,
    previouslyUsedOnramps: [MeldPreviouslyUsedOnramp]? = nil,
    serviceProviderCustomers: [MeldServiceProviderCustomer]? = nil
  ) {
    self.id = id
    self.accountId = accountId
    self.externalId = externalId
    self.key = key
    self.name = name
    self.email = email
    self.phone = phone
    self.dateOfBirth = dateOfBirth
    self.type = type
    self.status = status
    self.addresses = addresses
    self.emailVerifiedAt = emailVerifiedAt
    self.phoneVerifiedAt = phoneVerifiedAt
    self.verificationMeta = verificationMeta
    self.serviceProviders = serviceProviders
    self.previouslyUsedOnramps = previouslyUsedOnramps
    self.serviceProviderCustomers = serviceProviderCustomers
  }
}

/// One of a customer's addresses.
public struct MeldCustomerAddress: Codable, Equatable {
  public let id: String
  public let customerId: String
  public let type: MeldCustomerAddressType
  public let status: MeldCustomerStatus
  public let addressDetails: MeldCustomerAddressDetails

  public init(
    id: String,
    customerId: String,
    type: MeldCustomerAddressType,
    status: MeldCustomerStatus,
    addressDetails: MeldCustomerAddressDetails
  ) {
    self.id = id
    self.customerId = customerId
    self.type = type
    self.status = status
    self.addressDetails = addressDetails
  }
}

public struct MeldCustomerAddressDetails: Codable, Equatable {
  public let lineOne: String?
  public let lineTwo: String?
  public let city: String?
  public let region: String?
  public let postalCode: String?
  public let country: String?

  public init(
    lineOne: String? = nil,
    lineTwo: String? = nil,
    city: String? = nil,
    region: String? = nil,
    postalCode: String? = nil,
    country: String? = nil
  ) {
    self.lineOne = lineOne
    self.lineTwo = lineTwo
    self.city = city
    self.region = region
    self.postalCode = postalCode
    self.country = country
  }
}

/// A service provider the customer has used before, and when.
public struct MeldPreviouslyUsedOnramp: Codable, Equatable {
  /// ISO 8601 datetime.
  public let previouslyUsed: String
  public let serviceProvider: String

  public init(previouslyUsed: String, serviceProvider: String) {
    self.previouslyUsed = previouslyUsed
    self.serviceProvider = serviceProvider
  }
}

/// The customer's account at one service provider.
public struct MeldServiceProviderCustomer: Codable, Equatable {
  public let id: String
  public let customerId: String
  public let serviceProvider: String
  public let serviceProviderAccessProfileId: String?
  /// Provider-specific data, passed through as Meld returns it.
  public let serviceProviderDetails: [String: AnyCodable]?
  public let status: String?
  public let wallets: [String]?
  public let kyc: MeldServiceProviderCustomerKyc?
  public let createdAt: String?
  public let deletedAt: String?

  public init(
    id: String,
    customerId: String,
    serviceProvider: String,
    serviceProviderAccessProfileId: String? = nil,
    serviceProviderDetails: [String: AnyCodable]? = nil,
    status: String? = nil,
    wallets: [String]? = nil,
    kyc: MeldServiceProviderCustomerKyc? = nil,
    createdAt: String? = nil,
    deletedAt: String? = nil
  ) {
    self.id = id
    self.customerId = customerId
    self.serviceProvider = serviceProvider
    self.serviceProviderAccessProfileId = serviceProviderAccessProfileId
    self.serviceProviderDetails = serviceProviderDetails
    self.status = status
    self.wallets = wallets
    self.kyc = kyc
    self.createdAt = createdAt
    self.deletedAt = deletedAt
  }
}

/// The customer's KYC state at one service provider.
public struct MeldServiceProviderCustomerKyc: Codable, Equatable {
  /// Provider-specific data, passed through as Meld returns it.
  public let additionalInfo: [String: AnyCodable]?
  public let onboardingMethod: OnboardingMethod?
  public let status: MeldKycStatus?
  public let updatedAt: String?

  public struct OnboardingMethod: Codable, Equatable {
    public let kycProvider: String?
    public let onboardingType: String?

    public init(kycProvider: String? = nil, onboardingType: String? = nil) {
      self.kycProvider = kycProvider
      self.onboardingType = onboardingType
    }
  }

  public init(
    additionalInfo: [String: AnyCodable]? = nil,
    onboardingMethod: OnboardingMethod? = nil,
    status: MeldKycStatus? = nil,
    updatedAt: String? = nil
  ) {
    self.additionalInfo = additionalInfo
    self.onboardingMethod = onboardingMethod
    self.status = status
    self.updatedAt = updatedAt
  }
}

/// The result of `searchCustomer`: the client's Meld customer, if it has one.
public struct MeldCustomerSearchResult: Codable, Equatable {
  public let customers: [MeldCustomer]
  public let count: Int
  public let remaining: Int

  public init(customers: [MeldCustomer], count: Int, remaining: Int) {
    self.customers = customers
    self.count = count
    self.remaining = remaining
  }
}

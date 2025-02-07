//
//  MockPortalRequests.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

public actor MockPortalRequests: PortalRequestsProtocol {
  private let encoder = JSONEncoder()

  public init() {}

  public func delete(_ url: URL, withBearerToken _: String? = nil) async throws -> Data {
    switch url.path {
    default:
      guard let mockNullData = "null".data(using: .utf8) else {
        throw PortalRequestsError.couldNotParseHttpResponse
      }
      return mockNullData
    }
  }

  // Tracking variables for `get` function
  private(set) var getCallsCount = 0
  private(set) var getFromParam: URL?
  private(set) var getWithBearerTokenParam: String?

  public func get(_ url: URL, withBearerToken: String? = nil) async throws -> Data {
    getCallsCount += 1
    getFromParam = url
    getWithBearerTokenParam = withBearerToken

    switch url.path {
    case "/api/v3/clients/me":
      let mockClientData = try encoder.encode(MockConstants.mockClient)
      return mockClientData
    case "/api/v3/clients/me/balances":
      let mockBalancesData = try encoder.encode([MockConstants.mockedFetchedBalance])
      return mockBalancesData
    case "/api/v3/clients/me/transactions":
      let mockTransactionData = try encoder.encode([MockConstants.mockFetchedTransaction])
      return mockTransactionData
    case "/api/v3/clients/me/wallets/\(MockConstants.mockWalletId)/backup-share-pairs", "/api/v3/clients/me/wallets/\(MockConstants.mockWalletId)/signing-share-pairs":
      let mockSigningSharePairsData = try encoder.encode([MockConstants.mockFetchedShairPair])
      return mockSigningSharePairsData
    case "/drive/v3/files":
      let mockFilesListResponse = GDriveFilesListResponse(
        kind: "test-gdrive-file-kind",
        incompleteSearch: false,
        files: [MockConstants.mockGDriveFile]
      )
      let filesData = try encoder.encode(mockFilesListResponse)
      return filesData
    case "/drive/v3/files/\(MockConstants.mockGDriveFileId)":
      guard let contentsData = MockConstants.mockEncryptionKey.data(using: .utf8) else {
        throw PortalRequestsError.couldNotParseHttpResponse
      }
      return contentsData
    case "/passkeys/status":
      let statusData = try encoder.encode(MockConstants.mockPasskeyStatus)
      return statusData
    default:
      guard let mockNullData = "null".data(using: .utf8) else {
        throw PortalRequestsError.couldNotParseHttpResponse
      }
      return mockNullData
    }
  }

  public func patch(_ url: URL, withBearerToken _: String? = nil, andPayload _: Codable) async throws -> Data {
    switch url.path {
    case "/api/v3/clients/me/backup-share-pairs/", "/api/v3/clients/me/signing-share-pairs/":
      guard let mockTrueData = "true".data(using: .utf8) else {
        throw PortalRequestsError.couldNotParseHttpResponse
      }
      return mockTrueData
    default:
      guard let mockNullData = "null".data(using: .utf8) else {
        throw PortalRequestsError.couldNotParseHttpResponse
      }
      return mockNullData
    }
  }

  // Tracking variables for `post` function
  private(set) var postCallsCount = 0
  private(set) var postFromParam: URL?
  private(set) var postWithBearerTokenParam: String?
  private(set) var postAndPayloadParam: Codable?

  public func post(_ url: URL, withBearerToken: String? = nil, andPayload: Codable? = nil) async throws -> Data {
    postCallsCount += 1
    postFromParam = url
    postWithBearerTokenParam = withBearerToken
    postAndPayloadParam = andPayload

    switch url.path {
    case "/api/v1/analytics/identify", "/api/v1/analytics/track":
      let mockMetricsResponseData = try encoder.encode(MockConstants.mockMetricsResponse)
      return mockMetricsResponseData
    case "/api/v3/clients/me/eject":
      guard let mockEjectData = MockConstants.mockEjectResponse.data(using: .utf8) else {
        throw PortalRequestsError.couldNotParseHttpResponse
      }
      return mockEjectData
    case "/api/v3/clients/me/simulate-transaction":
      let mockSimulateTransactionData = try encoder.encode(MockConstants.mockSimulatedTransaction)
      return mockSimulateTransactionData
    case "/api/v3/clients/me/fund":
      let mockFundResponse = try encoder.encode(MockConstants.mockFundResponse)
      return mockFundResponse
    case "/drive/v3/files":
      let mockFilesListResponse = GDriveFilesListResponse(
        kind: "test-gdrive-file-kind",
        incompleteSearch: false,
        files: [MockConstants.mockGDriveFile]
      )
      let filesData = try encoder.encode(mockFilesListResponse)
      return filesData
    case "/passkeys/begin-login":
      let mockAuthenticationData = try encoder.encode(MockConstants.mockPasskeyAuthenticationOptions)
      return mockAuthenticationData
    case "/passkeys/begin-registration":
      let mockRegistrationData = try encoder.encode(MockConstants.mockPasskeyRegistrationOptions)
      return mockRegistrationData
    case "/passkeys/finish-login/read":
      let mockReadData = try encoder.encode(MockConstants.mockPasskeyReadResponse)
      return mockReadData
    case "/test-rpc":
      let mockRpcData = try encoder.encode(MockConstants.mockRpcResponse)
      return mockRpcData
    default:
      guard let mockNullData = "null".data(using: .utf8) else {
        throw PortalRequestsError.couldNotParseHttpResponse
      }
      return mockNullData
    }
  }

  public func postMultiPartData(
    _: URL,
    withBearerToken _: String,
    andPayload _: String,
    usingBoundary _: String
  ) async throws -> Data {
    let gDriveFileData = try JSONEncoder().encode(MockConstants.mockGDriveFile)
    return gDriveFileData
  }
}

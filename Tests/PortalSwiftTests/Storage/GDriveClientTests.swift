//
//  GDriveClientTests.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import GoogleSignIn
@testable import PortalSwift
import XCTest

final class GDriveClientTests: XCTestCase {
  var client: GDriveClient? = nil

  override func setUpWithError() throws {
    initGDriveClient()
  }

  override func tearDownWithError() throws {
    client = nil
  }
}

// MARK: - Test Helpers

extension GDriveClientTests {
  func initGDriveClient(
    requests: PortalRequestsProtocol? = nil
  ) {
    let portalRequests = requests ?? MockPortalRequests()
    client = GDriveClient(requests: portalRequests)
    client?.auth = MockGoogleAuth(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))
  }
}

// MARK: - delete tests

extension GDriveClientTests {
  func testDelete() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.delete(id)")
    let success = try await client?.delete(MockConstants.mockGDriveFileId) ?? false
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_delete_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.delete("")
      XCTFail("Expected error not thrown when calling GDriveClient.delete() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive"))
    }
  }

  func test_delete_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    _ = try await client?.delete("")

    // then
    XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_delete_willCall_executeRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    let id = "test-id"

    // and given
    _ = try await client?.delete(id)

    // then
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.method, .delete)
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.path(), "/drive/v3/files/\(id)")
  }
}

// MARK: - getIdForFilename tests

extension GDriveClientTests {
  func testGetIdForFilename() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.getIdForFilename(filename)")
    let fileId = try await client?.getIdForFilename(MockConstants.mockGDriveFileName, useAppDataFolder: false)
    XCTAssertEqual(fileId, MockConstants.mockGDriveFileId)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getIdForFilename_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.getIdForFilename("", useAppDataFolder: false)
      XCTFail("Expected error not thrown when calling GDriveClient.delete() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive"))
    }
  }

  func test_getIdForFilename_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [MockConstants.mockGDriveFile]
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try await client?.getIdForFilename("", useAppDataFolder: false)

    // then
    XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_getIdForFilename_willCall_executeRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    let fileName = "test-file-name"
    let query = "name='\(fileName).txt'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [MockConstants.mockGDriveFile]
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try await client?.getIdForFilename(fileName, useAppDataFolder: false)

    // then
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.path(), "/drive/v3/files")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.query(), "corpora=user&q=\(query)&orderBy=modifiedTime%20desc&pageSize=1")
  }

  @available(iOS 16.0, *)
  func test_getIdForFilename_forAppDataFolder_willCall_executeRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    let fileName = "test-file-name"
    let query = "name='\(fileName).txt'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [MockConstants.mockGDriveFile]
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try await client?.getIdForFilename(fileName, useAppDataFolder: true)

    // then
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.path(), "/drive/v3/files")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.query(), "spaces=appDataFolder&q=\(query)&orderBy=modifiedTime%20desc&pageSize=1")
  }

  func test_getIdForFilename_willThrowCorrectError_whenThereIsNoFileFound() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [] // no files found
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    do {
      // and given
      _ = try await client?.getIdForFilename("", useAppDataFolder: false)
      XCTFail("Expected error not thrown when calling GDriveClient.delete() when there is no file found.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.noFileFound)
    }
  }
}

// MARK: - read tests

extension GDriveClientTests {
  func testRead() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.read(id)")
    let response = try await client?.read(MockConstants.mockGDriveFileId)
    XCTAssertEqual(response, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_read_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.read("")
      XCTFail("Expected error not thrown when calling GDriveClient.read() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive"))
    }
  }

  func test_read_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    if let contentsData = MockConstants.mockEncryptionKey.data(using: .utf8) {
      portalRequestSpy.returnData = contentsData
    }

    // and given
    _ = try await client?.read("")

    // then
    XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_read_willCall_executeRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    let fileName = "test-file-name"

    // and given
    if let contentsData = MockConstants.mockEncryptionKey.data(using: .utf8) {
      portalRequestSpy.returnData = contentsData
    }

    // and given
    _ = try await client?.read(fileName)

    // then
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.path(), "/drive/v3/files/\(fileName)")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.query(), "alt=media")
  }

  func test_read_willThrowCorrectError_whenUnableToReadFileContent() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    portalRequestSpy.returnData = Data([0xFF, 0xFE, 0xFD]) // Data object containing the byte sequence [0xFF, 0xFE, 0xFD], This sequence is invalid in UTF-8 encoding, To enforce the throw.

    do {
      // and given
      _ = try await client?.read("")
      XCTFail("Expected error not thrown when calling GDriveClient.read() when unable to read the file content.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.unableToReadFileContents)
    }
  }
}

// MARK: - validateOperations tests

extension GDriveClientTests {
  func test_validateOperations_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.validateOperations()
      XCTFail("Expected error not thrown when calling GDriveClient.validateOperations() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive"))
    }
  }
}

// MARK: - write tests

extension GDriveClientTests {
  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.write()")
    let success = try await client?.write(MockConstants.mockEncryptionKey, withContent: MockConstants.mockEncryptionKey) ?? false
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_write_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.write("", withContent: "")
      XCTFail("Expected error not thrown when calling GDriveClient.write() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive"))
    }
  }
}

// MARK: - createFolder tests

extension GDriveClientTests {
  func test_createFolder_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.createFolder()
      XCTFail("Expected error not thrown when calling GDriveClient.read() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive"))
    }
  }

  func test_createFolder_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    let mockFilesListResponse = MockConstants.mockGDriveFile
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try await client?.createFolder()

    // then
    XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_createFolder_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    let mockFilesListResponse = MockConstants.mockGDriveFile
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    let payload = GDriveFolderMetadata(
      mimeType: "application/vnd.google-apps.folder",
      name: client?.folder ?? "",
      parents: ["root"]
    )

    // and given
    _ = try await client?.createFolder()

    // then
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.path(), "/drive/v3/files")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.query(), "ignoreDefaultVisibility=true")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.payload as? GDriveFolderMetadata, payload)
  }
}

// MARK: -  getOrCreateFolder tests

extension GDriveClientTests {
  func test_getOrCreateFolder_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.getOrCreateFolder()
      XCTFail("Expected error not thrown when calling GDriveClient.getOrCreateFolder() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive"))
    }
  }

  func test_getOrCreateFolder_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [MockConstants.mockGDriveFile]
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try await client?.getOrCreateFolder()

    // then
    XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_getOrCreateFolder_willCall_executeRequest_passingCorrectUrlPath() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    let query = "name='\(client?.folder ?? "")'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [MockConstants.mockGDriveFile]
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try await client?.getOrCreateFolder()

    // then
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.path(), "/drive/v3/files")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.query(), "q=\(query)")
  }

  @available(iOS 16.0, *)
  func test_getOrCreateFolder_willTryToGenerateFolder_whenThereIsNoFolder() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    let payload = GDriveFolderMetadata(
      mimeType: "application/vnd.google-apps.folder",
      name: client?.folder ?? "",
      parents: ["root"]
    )

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [] // no files to enforce creating file
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try? await client?.getOrCreateFolder()

    // then
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.path(), "/drive/v3/files")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.url.query(), "ignoreDefaultVisibility=true")
    XCTAssertEqual(portalRequestSpy.executeRequestParam?.payload as? GDriveFolderMetadata, payload)
  }
}

// MARK: - writeFile tests

extension GDriveClientTests {
  func test_writeFile_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.writeFile("", withContent: "", andAccessToken: "", useAppDataFolder: false)
      XCTFail("Expected error not thrown when calling GDriveClient.read() when there is no auth object.")
    } catch {
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive"))
    }
  }

  func test_writeFile_willCall_requestPostMultiPart_onlyOnce() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [MockConstants.mockGDriveFile]
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    // and given
    _ = try? await client?.writeFile("", withContent: "", andAccessToken: "", useAppDataFolder: false)

    // then
    XCTAssertEqual(portalRequestSpy.postMultiPartDataCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_writeFile_willCall_requestPostMultiPart_passingCorrectUrlPathAndPayload() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)

    // and given
    let mockFilesListResponse = GDriveFilesListResponse(
      kind: "test-gdrive-file-kind",
      incompleteSearch: false,
      files: [MockConstants.mockGDriveFile]
    )
    let filesData = try JSONEncoder().encode(mockFilesListResponse)
    portalRequestSpy.returnData = filesData

    let fileName = "test-file-name"
    let content = "test-content"
    let accessToken = "test-access-token"

    let metadata = GDriveFileMetadata(name: fileName, parents: [MockConstants.mockGDriveFile.id])
    let payload = try client?.buildMultipartFormData(
      content,
      withMetadata: metadata
    )

    // and given
    _ = try? await client?.writeFile(fileName, withContent: content, andAccessToken: accessToken, useAppDataFolder: false)

    // then
    XCTAssertEqual(portalRequestSpy.postMultiPartDataFromParam?.path(), "/upload/drive/v3/files")
    XCTAssertEqual(portalRequestSpy.postMultiPartDataFromParam?.query(), "ignoreDefaultVisibility=true&uploadType=multipart")
    XCTAssertTrue(areStringsEqualIgnoringOrder(portalRequestSpy.postMultiPartDataAndPayloadParam ?? "", payload ?? ""))
  }
}

// MARK: - buildMultipartFormData tests

extension GDriveClientTests {
  func test_buildMultipartFormData() throws {
    let content = "test-content"
    let boundary = "portal-backup-share"
    let metadata = GDriveFileMetadata(name: "test-file-name", parents: [MockConstants.mockGDriveFile.id])
    let metadataJSON = try JSONEncoder().encode(metadata)
    let metadataString = String(data: metadataJSON, encoding: .utf8)!
    let expectedFormData = [
      "--\(boundary)\n",
      "Content-Type: application/json; charset=UTF-8\n\n",
      "\(metadataString)\n",
      "--\(boundary)\n",
      "Content-Type: text/plain\n\n",
      "\(content)\n",
      "--\(boundary)--"
    ].joined(separator: "")

    let result = (try? client?.buildMultipartFormData(content, withMetadata: metadata)) ?? ""

    XCTAssertTrue(areStringsEqualIgnoringOrder(result, expectedFormData))
  }
}

// MARK: - Helper functions

extension GDriveClientTests {
  /// Use it to check if two payloads equal regardless of the
  private func areStringsEqualIgnoringOrder(_ string1: String, _ string2: String) -> Bool {
    func extractJsonContent(from string: String) -> String? {
      // Find the JSON content in the string
      if let jsonStart = string.range(of: "{"),
         let jsonEnd = string.range(of: "}", options: .backwards)
      {
        let jsonString = String(string[jsonStart.lowerBound ... jsonEnd.upperBound])
        return jsonString
      }
      return nil
    }

    func parseJson(_ jsonString: String) -> [String: Any]? {
      guard let data = jsonString.data(using: .utf8) else { return nil }
      return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }

    // Extract JSON content
    guard let json1 = extractJsonContent(from: string1),
          let json2 = extractJsonContent(from: string2)
    else {
      return false
    }

    // Parse the JSON objects
    guard let jsonObject1 = parseJson(json1),
          let jsonObject2 = parseJson(json2)
    else {
      return false
    }

    // Compare the JSON objects
    return NSDictionary(dictionary: jsonObject1).isEqual(to: jsonObject2)
  }
}

// MARK: - scope wiring tests

extension GDriveClientTests {
  @MainActor
  func test_auth_requestsBothScopes_whenBackupOptionIsNil() {
    // given the legacy configuration path (clientId + view, no backup option)
    let client = GDriveClient(clientId: MockConstants.mockGDriveClientId, view: UIViewController(), requests: MockPortalRequests())

    // then
    XCTAssertEqual(
      client.auth?.requiredScopes,
      [GDriveBackupOption.DriveScope.file, GDriveBackupOption.DriveScope.appData]
    )
  }

  @MainActor
  func test_auth_requestsAppDataOnly_whenOptionIsSetAfterAuthWasBuilt() {
    // given an auth built before any backup option exists
    let client = GDriveClient(clientId: MockConstants.mockGDriveClientId, view: UIViewController(), requests: MockPortalRequests())

    // and given the option changes without the auth being rebuilt
    client.backupOption = .appDataFolder

    // then the live auth resolves the new option's scopes
    XCTAssertEqual(client.auth?.requiredScopes, [GDriveBackupOption.DriveScope.appData])
  }

  @MainActor
  func test_auth_requestsLatestOptionScopes_afterOptionMutation() {
    // given
    let client = GDriveClient(clientId: MockConstants.mockGDriveClientId, view: UIViewController(), requests: MockPortalRequests())
    client.backupOption = .appDataFolder
    let auth = client.auth

    // and given the option changes again on the same auth instance
    client.backupOption = .gdriveFolder(folderName: "test-folder")

    // then
    XCTAssertEqual(auth?.requiredScopes, [GDriveBackupOption.DriveScope.file])
  }

  @MainActor
  func test_auth_reflectsOption_whenClientIdIsSetAfterOption() {
    // given the PortalMpc.setGDriveConfiguration ordering (option first, clientId second)
    let client = GDriveClient(view: UIViewController(), requests: MockPortalRequests())
    client.backupOption = .appDataFolder
    client.clientId = MockConstants.mockGDriveClientId

    // then
    XCTAssertEqual(client.auth?.requiredScopes, [GDriveBackupOption.DriveScope.appData])
  }

  @MainActor
  func test_auth_reflectsOption_afterViewReassignmentRebuildsAuth() {
    // given a configured client
    let client = GDriveClient(clientId: MockConstants.mockGDriveClientId, view: UIViewController(), requests: MockPortalRequests())
    client.backupOption = .appDataFolderWithFallback
    let originalAuth = client.auth

    // and given setGDriveView is called again (the example apps do this on every backup)
    client.view = UIViewController()

    // then the rebuilt auth still resolves the configured option's scopes
    XCTAssertFalse(client.auth === originalAuth)
    XCTAssertEqual(
      client.auth?.requiredScopes,
      [GDriveBackupOption.DriveScope.file, GDriveBackupOption.DriveScope.appData]
    )
  }
}

// MARK: - recoverFiles tests

private class EmptyTokenGoogleAuth: GoogleAuth {
  override func getAccessToken() async -> String {
    return ""
  }
}

/// Returns a valid token for the first fetch (the recoverFiles pre-flight) and
/// an empty token for every fetch after it, simulating the grant dying while
/// the recovery loop is running.
private class TokenLostAfterPreflightGoogleAuth: GoogleAuth {
  private(set) var getAccessTokenCallsCount = 0

  override func getAccessToken() async -> String {
    getAccessTokenCallsCount += 1
    return getAccessTokenCallsCount == 1 ? MockConstants.mockGoogleAccessToken : ""
  }
}

extension GDriveClientTests {
  func test_recoverFiles_willReturnRecoveredFiles_whenTokenIsValid() async throws {
    // given
    let hashes = ["default": MockConstants.mockGDriveFileName]

    // and given
    let recoveredFiles = try await client?.recoverFiles(for: hashes, useAppDataFolder: false)

    // then
    XCTAssertEqual(recoveredFiles?["default"], MockConstants.mockEncryptionKey)
  }

  func test_recoverFiles_willThrowCorrectError_whenThereIsNoAuth() async throws {
    // given
    client?.auth = nil

    do {
      // and given
      _ = try await client?.recoverFiles(for: ["default": MockConstants.mockGDriveFileName], useAppDataFolder: false)
      XCTFail("Expected error not thrown when calling GDriveClient.recoverFiles() when there is no auth object.")
    } catch {
      // then
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive"))
    }
  }

  func test_recoverFiles_willThrowUserNotAuthenticated_beforeAnyDriveRequest_whenAccessTokenIsEmpty() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    client?.auth = EmptyTokenGoogleAuth(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))

    do {
      // and given
      _ = try await client?.recoverFiles(for: ["default": MockConstants.mockGDriveFileName], useAppDataFolder: false)
      XCTFail("Expected error not thrown when calling GDriveClient.recoverFiles() with an empty access token.")
    } catch {
      // then
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.userNotAuthenticated)
      XCTAssertEqual(portalRequestSpy.executeCallsCount, 0)
    }
  }

  func test_recoverFiles_willRethrowUserNotAuthenticated_insteadOfCollectingIt_whenAccessTokenIsLostAfterPreflight() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    let auth = TokenLostAfterPreflightGoogleAuth(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))
    client?.auth = auth
    let hashes = [
      "default": MockConstants.mockGDriveFileName,
      "ios": MockConstants.mockGDriveFileName + "-ios",
      "android": MockConstants.mockGDriveFileName + "-android"
    ]

    do {
      // and given
      _ = try await client?.recoverFiles(for: hashes, useAppDataFolder: false)
      XCTFail("Expected error not thrown when calling GDriveClient.recoverFiles() and the access token is lost after the pre-flight.")
    } catch {
      // then: the auth failure surfaces as-is so GDriveStorage.read() can skip the folder fallback...
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.userNotAuthenticated)
      // ...the loop stops at the first failed fetch instead of re-fetching (and re-prompting) per remaining hash...
      XCTAssertEqual(auth.getAccessTokenCallsCount, 2)
      // ...and no Drive request was made with an empty token.
      XCTAssertEqual(portalRequestSpy.executeCallsCount, 0)
    }
  }
}

// MARK: - createFolder tests

extension GDriveClientTests {
  func test_createFolder_willThrowUserNotAuthenticated_beforeAnyDriveRequest_whenAccessTokenIsEmpty() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    initGDriveClient(requests: portalRequestSpy)
    client?.auth = EmptyTokenGoogleAuth(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))

    do {
      // and given
      _ = try await client?.createFolder()
      XCTFail("Expected error not thrown when calling GDriveClient.createFolder() with an empty access token.")
    } catch {
      // then
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.userNotAuthenticated)
      XCTAssertEqual(portalRequestSpy.executeCallsCount, 0)
    }
  }
}

// MARK: - rejected access token recovery tests

/// Returns the scripted tokens in order (the last one repeats), so a test can
/// model a session that only renews after signOut(), or one already renewed by
/// an earlier recovery in the same operation.
private class ScriptedTokenGoogleAuth: MockGoogleAuth {
  var tokens: [String]
  var signOutCallsCount = 0

  init(tokens: [String]) {
    self.tokens = tokens
    super.init(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))
  }

  override func getAccessToken() async -> String {
    return tokens.count > 1 ? tokens.removeFirst() : tokens[0]
  }

  override func signOut() {
    signOutCallsCount += 1
  }
}

extension GDriveClientTests {
  func test_read_willSignOutAndRetryOnce_whenDriveRejectsTheStoredToken() async throws {
    // given Drive rejects the token the silent restore keeps returning until we sign out
    let portalRequestSpy = PortalRequestsSpy()
    portalRequestSpy.returnData = Data("file-contents".utf8)
    portalRequestSpy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    initGDriveClient(requests: portalRequestSpy)
    let auth = ScriptedTokenGoogleAuth(tokens: ["revoked-token", "revoked-token", "fresh-token"])
    client?.auth = auth

    // and given
    let contents = try await client?.read(MockConstants.mockGDriveFileId)

    // then
    XCTAssertEqual(contents, "file-contents")
    XCTAssertEqual(auth.signOutCallsCount, 1)
    XCTAssertEqual(portalRequestSpy.executeCallsCount, 2)
  }

  func test_read_willRetryWithoutSignOut_whenSessionWasAlreadyRenewed() async throws {
    // given an earlier recovery in the same operation already renewed the session
    let portalRequestSpy = PortalRequestsSpy()
    portalRequestSpy.returnData = Data("file-contents".utf8)
    portalRequestSpy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    initGDriveClient(requests: portalRequestSpy)
    let auth = ScriptedTokenGoogleAuth(tokens: ["stale-token", "fresh-token"])
    client?.auth = auth

    // and given
    let contents = try await client?.read(MockConstants.mockGDriveFileId)

    // then no second prompt: the renewed token is used as-is
    XCTAssertEqual(contents, "file-contents")
    XCTAssertEqual(auth.signOutCallsCount, 0)
    XCTAssertEqual(portalRequestSpy.executeCallsCount, 2)
  }

  func test_read_willThrowUserNotAuthenticated_whenDriveRejectsTheRenewedTokenToo() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    portalRequestSpy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, PortalRequestsError.unauthorized]
    initGDriveClient(requests: portalRequestSpy)
    let auth = ScriptedTokenGoogleAuth(tokens: ["revoked-token", "revoked-token", "fresh-token"])
    client?.auth = auth

    do {
      // and given
      _ = try await client?.read(MockConstants.mockGDriveFileId)
      XCTFail("Expected error not thrown when Drive rejects the renewed token as well.")
    } catch {
      // then exactly one retry, reported as an authentication failure so loops fail once
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.userNotAuthenticated)
      XCTAssertEqual(auth.signOutCallsCount, 1)
      XCTAssertEqual(portalRequestSpy.executeCallsCount, 2)
    }
  }

  func test_read_willThrowUserNotAuthenticated_whenFreshSignInFailsAfterRejection() async throws {
    // given the fallback sign-in is declined (no token comes back)
    let portalRequestSpy = PortalRequestsSpy()
    portalRequestSpy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    initGDriveClient(requests: portalRequestSpy)
    let auth = ScriptedTokenGoogleAuth(tokens: ["revoked-token", "revoked-token", ""])
    client?.auth = auth

    do {
      // and given
      _ = try await client?.read(MockConstants.mockGDriveFileId)
      XCTFail("Expected error not thrown when the fresh sign-in yields no token.")
    } catch {
      // then
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.userNotAuthenticated)
      XCTAssertEqual(auth.signOutCallsCount, 1)
      XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
    }
  }

  func test_read_willNotSignOut_whenDriveFailsForOtherReasons() async throws {
    // given
    let portalRequestSpy = PortalRequestsSpy()
    portalRequestSpy.executeThrowableErrorSequence = [URLError(.timedOut)]
    initGDriveClient(requests: portalRequestSpy)
    let auth = ScriptedTokenGoogleAuth(tokens: ["token"])
    client?.auth = auth

    do {
      // and given
      _ = try await client?.read(MockConstants.mockGDriveFileId)
      XCTFail("Expected error not thrown when the Drive request fails.")
    } catch {
      // then the session is left alone
      XCTAssertEqual((error as? URLError)?.code, .timedOut)
      XCTAssertEqual(auth.signOutCallsCount, 0)
      XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
    }
  }

  func test_writeFile_willSignOutAndRetryUploadOnce_whenDriveRejectsTheStoredToken() async throws {
    // given the folder lookup succeeds but the upload is rejected with the stored token
    let portalRequestSpy = PortalRequestsSpy()
    portalRequestSpy.returnData = try JSONEncoder().encode(MockConstants.mockGDriveFile)
    portalRequestSpy.postMultiPartDataThrowableErrorSequence = [PortalRequestsError.unauthorized]
    initGDriveClient(requests: portalRequestSpy)
    let auth = ScriptedTokenGoogleAuth(tokens: ["revoked-token", "revoked-token", "fresh-token"])
    client?.auth = auth

    // and given
    let fileId = try await client?.writeFile(
      MockConstants.mockGDriveFileName,
      withContent: "content",
      andAccessToken: "revoked-token",
      useAppDataFolder: true
    )

    // then the upload is retried with the renewed token
    XCTAssertEqual(fileId, MockConstants.mockGDriveFileId)
    XCTAssertEqual(auth.signOutCallsCount, 1)
    XCTAssertEqual(portalRequestSpy.postMultiPartDataCallsCount, 2)
    XCTAssertEqual(portalRequestSpy.postMultiPartDataWithBearerTokenParam, "fresh-token")
  }
}

// MARK: - write recovery tests

extension GDriveClientTests {
  func test_write_willNotFallBackToWriteFile_whenRecoverySignInIsDeclined() async throws {
    // given Drive rejects the cached token during the existing-file lookup and
    // the user declines the recovery sign-in
    let portalRequestSpy = PortalRequestsSpy()
    portalRequestSpy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    initGDriveClient(requests: portalRequestSpy)
    let auth = ScriptedTokenGoogleAuth(tokens: ["revoked-token", "revoked-token", ""])
    client?.auth = auth
    client?.backupOption = .appDataFolder

    do {
      // and given
      _ = try await client?.write(MockConstants.mockGDriveFileName, withContent: "content")
      XCTFail("Expected error not thrown when calling GDriveClient.write() after the recovery sign-in was declined.")
    } catch {
      // then the "no existing file" fallback must not run and prompt a second time
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.userNotAuthenticated)
      XCTAssertEqual(auth.signOutCallsCount, 1)
      XCTAssertEqual(portalRequestSpy.executeCallsCount, 1)
      XCTAssertEqual(portalRequestSpy.postMultiPartDataCallsCount, 0)
    }
  }
}

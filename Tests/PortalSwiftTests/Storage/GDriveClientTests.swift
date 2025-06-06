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

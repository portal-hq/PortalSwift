//
//  GDriveClient.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn

public enum GDriveClientError: Error, Equatable {
  case authenticationNotInitialized(String)
  case fileContentMismatch
  case noFileFound
  case unableToBuildGDriveQuery
  case unableToDeleteFromGDrive
  case unableToReadFileContents
  case unableToWriteToGDrive
  case userNotAuthenticated
  case viewNotInitialized(String)
}

public protocol GDriveClientProtocol {
  var auth: GoogleAuth? { get set }
  var clientId: String? { get set }
  var folder: String { get set }
  var view: UIViewController? { get set }
  func delete(_ key: String) async throws -> Bool
  func getAccessToken() async throws -> String
  func getIdForFilename(_ filename: String) async throws -> String
  func read(_ id: String) async throws -> String
  func validateOperations() async throws -> Bool
  func write(_ filename: String, withContent: String) async throws -> Bool
}

public class GDriveClient: GDriveClientProtocol {
  public var auth: GoogleAuth?
  public var clientId: String? {
    get { return self._clientId }
    set(clientId) {
      self._clientId = clientId

      if let clientId = clientId, let view = view {
        self.auth = GoogleAuth(config: GIDConfiguration(clientID: clientId), view: view)
      }
    }
  }

  public var folder: String
  public var view: UIViewController? {
    get { return self._view }
    set(view) {
      self._view = view

      if let clientId = clientId, let view = view {
        self.auth = GoogleAuth(config: GIDConfiguration(clientID: clientId), view: view)
      }
    }
  }

  private var _clientId: String?
  private var _view: UIViewController?
  private var api: HttpRequester
  private var baseUrl: String = "https://www.googleapis.com"
  private let boundary: String = "portal-backup-share"
  private let decoder = JSONDecoder()
  private let logger = PortalLogger()
  private let requests: PortalRequestsProtocol

  init(
    clientId: String? = nil,
    view: UIViewController? = nil,
    folder: String? = "_PORTAL_MPC_DO_NOT_DELETE_",
    requests: PortalRequestsProtocol? = nil
  ) {
    self._clientId = clientId
    self._view = view

    self.api = HttpRequester(baseUrl: self.baseUrl)
    self.folder = folder ?? "_PORTAL_MPC_DO_NOT_DELETE_"
    self.requests = requests ?? PortalRequests()

    if let clientId = _clientId, let view = _view {
      self.auth = GoogleAuth(config: GIDConfiguration(clientID: clientId), view: view)
    }
  }

  public func delete(_ id: String) async throws -> Bool {
    guard let auth = auth else {
      self.logger.error("GDriveClient.delete() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files/\(id)") {
      let _ = try await requests.delete(url, withBearerToken: accessToken)
      return true
    }

    throw URLError(.badURL)
  }

  public func getAccessToken() async throws -> String {
    guard let auth = auth else {
      self.logger.error("GDriveClient.getAccessToken() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive")
    }

    return await auth.getAccessToken()
  }

  public func getIdForFilename(_ filename: String) async throws -> String {
    guard let auth = auth else {
      self.logger.error("GDriveClient.getIdForFilename() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    let query = "name='\(filename)'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    guard let query = query else {
      throw GDriveClientError.unableToBuildGDriveQuery
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files?corpora=user&q=\(query)") {
      let data = try await requests.get(url, withBearerToken: accessToken)
      let filesListResponse = try decoder.decode(GDriveFilesListResponse.self, from: data)

      if filesListResponse.files.count > 0 {
        return filesListResponse.files[0].id
      }

      throw GDriveClientError.noFileFound
    }

    throw URLError(.badURL)
  }

  public func read(_ id: String) async throws -> String {
    guard let auth = auth else {
      self.logger.error("GDriveClient.read() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files/\(id)?alt=media") {
      let data = try await requests.get(url, withBearerToken: accessToken)

      guard let fileContents = String(data: data, encoding: .utf8) else {
        throw GDriveClientError.unableToReadFileContents
      }

      return fileContents
    }

    throw URLError(.badURL)
  }

  public func validateOperations() async throws -> Bool {
    guard let auth = auth else {
      self.logger.error("GDriveClient.validateOperations() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let mockFileName = "portal_test.txt"
    let mockContent = "test_value"
    let accessToken = await auth.getAccessToken()

    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    guard try await self.write(mockFileName, withContent: mockContent) else {
      throw GDriveClientError.unableToWriteToGDrive
    }

    let fileId = try await getIdForFilename(mockFileName)

    let fileContents = try await read(fileId)
    guard fileContents == mockContent else {
      throw GDriveClientError.fileContentMismatch
    }

    return try await self.delete(fileId)
  }

  public func write(_ filename: String, withContent: String) async throws -> Bool {
    guard let auth = auth else {
      self.logger.error("GDriveClient.write() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    do {
      let existingFileId = try await getIdForFilename(filename)
      guard try await self.delete(existingFileId) else {
        throw GDriveClientError.unableToDeleteFromGDrive
      }

      let fileId = try await writeFile(filename, withContent: withContent, andAccessToken: accessToken)

      return !fileId.isEmpty
    } catch {
      let fileId = try await writeFile(filename, withContent: withContent, andAccessToken: accessToken)

      return !fileId.isEmpty
    }
  }

  func createFolder() async throws -> GDriveFile {
    guard let auth = auth else {
      self.logger.error("GDriveClient.createFolder() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()

    if let url = URL(string: "\(baseUrl)/drive/v3/files?ignoreDefaultVisibility=true") {
      let payload = GDriveFolderMetadata(
        mimeType: "application/vnd.google-apps.folder",
        name: self.folder,
        parents: ["root"]
      )
      let data = try await requests.post(url, withBearerToken: accessToken, andPayload: payload)
      let file = try decoder.decode(GDriveFile.self, from: data)

      return file
    }

    throw URLError(.badURL)
  }

  func getOrCreateFolder() async throws -> GDriveFile {
    guard let auth = auth else {
      self.logger.error("GDriveClient.getOrCreateFolder() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    guard let query = "name='\(folder)'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      throw GDriveClientError.unableToBuildGDriveQuery
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files?q=\(query)") {
      let data = try await requests.get(url, withBearerToken: accessToken)
      let filesListResponse = try decoder.decode(GDriveFilesListResponse.self, from: data)

      if filesListResponse.files.count > 0 {
        return filesListResponse.files[0]
      }

      let folder = try await createFolder()

      return folder
    }

    throw URLError(.badURL)
  }

  func writeFile(_ filename: String, withContent: String, andAccessToken: String) async throws -> String {
    let folder = try await getOrCreateFolder()

    if let url = URL(string: "\(baseUrl)/upload/drive/v3/files?ignoreDefaultVisibility=true&uploadType=multipart") {
      let metadata = GDriveFileMetadata(name: filename, parents: [folder.id])
      let body = try self.buildMultipartFormData(
        withContent,
        withMetadata: metadata
      )

      let data = try await requests.postMultiPartData(
        url,
        withBearerToken: andAccessToken,
        andPayload: body,
        usingBoundary: self.boundary
      )
      let file = try decoder.decode(GDriveFile.self, from: data)

      return file.id
    }

    throw URLError(.badURL)
  }

  func buildMultipartFormData(_ content: String, withMetadata: GDriveFileMetadata) throws -> String {
    let metadataJSON = try JSONEncoder().encode(withMetadata)
    let metadataString = String(data: metadataJSON, encoding: .utf8)!
    let body = [
      "--\(boundary)\n",
      "Content-Type: application/json; charset=UTF-8\n\n",
      "\(metadataString)\n",
      "--\(boundary)\n",
      "Content-Type: text/plain\n\n",
      "\(content)\n",
      "--\(boundary)--"
    ]

    return body.joined(separator: "")
  }
}

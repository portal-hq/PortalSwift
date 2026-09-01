//
//  GDriveClient.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn

public enum GDriveClientError: LocalizedError, Equatable {
  case authenticationNotInitialized(String)
  case fileContentMismatch
  case noFileFound
  case unableToBuildGDriveQuery
  case unableToDeleteFromGDrive
  case unableToReadFileContents
  case unableToWriteToGDrive
  case userNotAuthenticated
  case viewNotInitialized(String)
  case unableToRecoverAnyFiles(errors: [String: Error])

  public static func == (lhs: GDriveClientError, rhs: GDriveClientError) -> Bool {
    switch (lhs, rhs) {
    case (.authenticationNotInitialized(let lhsMessage), .authenticationNotInitialized(let rhsMessage)):
      return lhsMessage == rhsMessage
    case (.fileContentMismatch, .fileContentMismatch),
         (.noFileFound, .noFileFound),
         (.unableToBuildGDriveQuery, .unableToBuildGDriveQuery),
         (.unableToDeleteFromGDrive, .unableToDeleteFromGDrive),
         (.unableToReadFileContents, .unableToReadFileContents),
         (.unableToWriteToGDrive, .unableToWriteToGDrive),
         (.userNotAuthenticated, .userNotAuthenticated):
      return true
    case (.viewNotInitialized(let lhsMessage), .viewNotInitialized(let rhsMessage)):
      return lhsMessage == rhsMessage
    case (.unableToRecoverAnyFiles(let lhsErrors), .unableToRecoverAnyFiles(let rhsErrors)):
      return lhsErrors.keys == rhsErrors.keys
    default:
      return false
    }
  }
}

public protocol GDriveClientProtocol {
  var auth: GoogleAuth? { get set }
  var clientId: String? { get set }
  var folder: String { get set }
  var backupOption: GDriveBackupOption? { get set }
  var view: UIViewController? { get set }
  func delete(_ key: String) async throws -> Bool
  func getAccessToken() async throws -> String
  func getIdForFilename(_ filename: String, useAppDataFolder: Bool) async throws -> String
  func read(_ id: String) async throws -> String
  func validateOperations() async throws -> Bool
  func write(_ filename: String, withContent: String) async throws -> Bool
  func recoverFiles(for hashes: [String: String], useAppDataFolder: Bool) async throws -> [String: String]
}

public class GDriveClient: GDriveClientProtocol {
  public var auth: GoogleAuth?
  public var clientId: String? {
    get { return self._clientId }
    set(clientId) {
      self._clientId = clientId

      if let clientId = clientId, let view = view {
        self.auth = self.makeGoogleAuth(clientId: clientId, view: view)
      }
    }
  }

  public var folder: String
  public var backupOption: GDriveBackupOption?

  public var view: UIViewController? {
    get { return self._view }
    set(view) {
      self._view = view

      if let clientId = clientId, let view = view {
        self.auth = self.makeGoogleAuth(clientId: clientId, view: view)
      }
    }
  }

  private var _clientId: String?
  private var _view: UIViewController?
  private var baseUrl: String = "https://www.googleapis.com"
  private let boundary: String = "portal-backup-share"
  private let decoder = JSONDecoder()
  private let logger = PortalLogger.shared
  private let requests: PortalRequestsProtocol

  init(
    clientId: String? = nil,
    view: UIViewController? = nil,
    folder: String? = "_PORTAL_MPC_DO_NOT_DELETE_",
    requests: PortalRequestsProtocol? = nil
  ) {
    self._clientId = clientId
    self._view = view

    self.folder = folder ?? "_PORTAL_MPC_DO_NOT_DELETE_"
    self.requests = requests ?? PortalRequests()

    if let clientId = _clientId, let view = _view {
      self.auth = self.makeGoogleAuth(clientId: clientId, view: view)
    }
  }

  private func makeGoogleAuth(clientId: String, view: UIViewController) -> GoogleAuth {
    GoogleAuth(
      config: GIDConfiguration(clientID: clientId),
      view: view,
      scopesProvider: { [weak self] in
        // Resolved at sign-in time so backupOption changes made after this
        // GoogleAuth was built are always honored.
        self?.backupOption?.requiredDriveScopes ?? GDriveBackupOption.legacyDriveScopes
      }
    )
  }

  /// Sends one Drive request and, when Drive rejects the access token (HTTP
  /// 401) that the silent restore still considered valid, retries exactly once
  /// with a renewed token — see `GoogleAuth.recoverFromRejectedAccessToken`.
  private func sendAuthorized<Response>(
    _ auth: GoogleAuth,
    _ accessToken: String,
    _ send: (String) async throws -> Response
  ) async throws -> Response {
    do {
      return try await send(accessToken)
    } catch PortalRequestsError.unauthorized {
      let renewedToken = await auth.recoverFromRejectedAccessToken(accessToken)
      if renewedToken.isEmpty {
        throw GDriveClientError.userNotAuthenticated
      }

      do {
        return try await send(renewedToken)
      } catch PortalRequestsError.unauthorized {
        // Drive rejected a token from a fresh sign-in as well; report it as an
        // authentication failure so callers fail once instead of re-prompting.
        throw GDriveClientError.userNotAuthenticated
      }
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
      _ = try await sendAuthorized(auth, accessToken) { token in
        try await requests.execute(
          request: PortalAPIRequest(url: url, method: .delete, bearerToken: token), mappingInResponse: Data.self
        )
      }
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

  public func getIdForFilename(_ filename: String, useAppDataFolder: Bool) async throws -> String {
    guard let auth = auth else {
      self.logger.error("GDriveClient.getIdForFilename() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    let filenameWithExtension = filename + ".txt"
    let query = "name='\(filenameWithExtension)'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    guard let query = query else {
      throw GDriveClientError.unableToBuildGDriveQuery
    }

    var spaces = "corpora=user"
    if useAppDataFolder {
      spaces = "spaces=appDataFolder"
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files?\(spaces)&q=\(query)&orderBy=modifiedTime%20desc&pageSize=1") {
      let filesListResponse = try await sendAuthorized(auth, accessToken) { token in
        try await requests.execute(request: PortalAPIRequest(url: url, bearerToken: token), mappingInResponse: GDriveFilesListResponse.self)
      }

      if filesListResponse.files.count > 0 {
        return filesListResponse.files[0].id
      }

      self.logger.info("GDriveClient.getIdForFilename() - No file found for: \(filenameWithExtension)")
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
      let fileData = try await sendAuthorized(auth, accessToken) { token in
        try await requests.execute(request: PortalAPIRequest(url: url, bearerToken: token), mappingInResponse: Data.self)
      }

      guard let fileContents = String(data: fileData, encoding: .utf8) else {
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

    let useAppDataFolder = backupOption?.usesAppDataFolder ?? false
    let fileId = try await getIdForFilename(mockFileName, useAppDataFolder: useAppDataFolder)

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

    let filenameWithExtension = filename + ".txt"

    let useAppDataFolder = backupOption?.usesAppDataFolder ?? false

    do {
      let existingFileId = try await getIdForFilename(filename, useAppDataFolder: useAppDataFolder)
      guard try await self.delete(existingFileId) else {
        throw GDriveClientError.unableToDeleteFromGDrive
      }

      let fileId = try await writeFile(filenameWithExtension, withContent: withContent, andAccessToken: accessToken, useAppDataFolder: useAppDataFolder)

      return !fileId.isEmpty
    } catch GDriveClientError.userNotAuthenticated {
      // The fallback below exists for "no existing file to replace"; running it
      // after a declined recovery sign-in would present the sheet a second time.
      throw GDriveClientError.userNotAuthenticated
    } catch {
      let fileId = try await writeFile(filenameWithExtension, withContent: withContent, andAccessToken: accessToken, useAppDataFolder: useAppDataFolder)

      return !fileId.isEmpty
    }
  }

  public func recoverFiles(for hashes: [String: String], useAppDataFolder: Bool) async throws -> [String: String] {
    guard let auth = auth else {
      self.logger.error("GDriveClient.recoverFiles() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive")
    }

    // One up-front token fetch so a missing or declined consent fails the whole
    // recovery once, instead of re-presenting the prompt for every hash below.
    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    var recoveredFiles: [String: String] = [:]
    var errors: [String: Error] = [:]
    var processedHashes: Set<String> = []

    for (platform, hash) in hashes {
      if processedHashes.contains(hash) {
        self.logger.info("GDriveClient.recoverFiles() - Skipping duplicate hash for platform: \(platform), hash: \(hash)")
        continue
      }

      do {
        let fileId = try await getIdForFilename(hash, useAppDataFolder: useAppDataFolder)
        let content = try await read(fileId)
        recoveredFiles[platform] = content
        processedHashes.insert(hash)
      } catch GDriveClientError.userNotAuthenticated {
        // The calls above fetch the access token again. If that fetch fails
        // mid-loop, collecting the error would let the remaining hashes (and
        // the caller's folder fallback) re-present the consent prompt, so
        // fail the whole recovery here just like the pre-flight does.
        throw GDriveClientError.userNotAuthenticated
      } catch {
        self.logger.info("GDriveClient.recoverFiles() - Error recovering file for platform: \(platform), hash: \(hash). Error: \(error)")
        errors[platform] = error
      }
    }

    if recoveredFiles.isEmpty {
      throw GDriveClientError.unableToRecoverAnyFiles(errors: errors)
    }

    return recoveredFiles
  }

  func createFolder() async throws -> GDriveFile {
    guard let auth = auth else {
      self.logger.error("GDriveClient.createFolder() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files?ignoreDefaultVisibility=true") {
      let payload = GDriveFolderMetadata(
        mimeType: "application/vnd.google-apps.folder",
        name: self.folder,
        parents: ["root"]
      )

      let file = try await sendAuthorized(auth, accessToken) { token in
        try await requests.execute(request: PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: token), mappingInResponse: GDriveFile.self)
      }

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
      let filesListResponse = try await sendAuthorized(auth, accessToken) { token in
        try await requests.execute(request: PortalAPIRequest(url: url, bearerToken: token), mappingInResponse: GDriveFilesListResponse.self)
      }

      if filesListResponse.files.count > 0 {
        return filesListResponse.files[0]
      }

      let folder = try await createFolder()

      return folder
    }

    throw URLError(.badURL)
  }

  private func getAppDataFolder() async throws -> GDriveFile {
    guard let auth = auth else {
      self.logger.error("GDriveClient.getAppDataFolder() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfig() to configure GoogleDrive")
    }

    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files/appDataFolder") {
      return try await sendAuthorized(auth, accessToken) { token in
        try await requests.execute(request: PortalAPIRequest(url: url, bearerToken: token), mappingInResponse: GDriveFile.self)
      }
    }

    throw URLError(.badURL)
  }

  func writeFile(_ filename: String, withContent: String, andAccessToken: String, useAppDataFolder: Bool) async throws -> String {
    guard let auth = auth else {
      self.logger.error("GDriveClient.writeFile() - Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive")
    }

    let folder = try await useAppDataFolder ? getAppDataFolder() : getOrCreateFolder()

    if let url = URL(string: "\(baseUrl)/upload/drive/v3/files?ignoreDefaultVisibility=true&uploadType=multipart") {
      let metadata = GDriveFileMetadata(name: filename, parents: [folder.id])
      let body = try self.buildMultipartFormData(
        withContent,
        withMetadata: metadata
      )

      let data = try await sendAuthorized(auth, andAccessToken) { token in
        try await requests.postMultiPartData(
          url,
          withBearerToken: token,
          andPayload: body,
          usingBoundary: self.boundary
        )
      }
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

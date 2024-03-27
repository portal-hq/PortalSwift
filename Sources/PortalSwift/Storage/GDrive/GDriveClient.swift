//
//  GDriveClient.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn

public enum GDriveClientError: Error {
  case fileContentMismatch
  case noFileFound
  case unableToBuildGDriveQuery
  case unableToDeleteFromGDrive
  case unableToReadFileContents
  case unableToWriteToGDrive
  case userNotAuthenticated
}

class GDriveClient {
  private var api: HttpRequester
  public var auth: GoogleAuth
  private var baseUrl: String = "https://www.googleapis.com"
  private var boundary: String = "portal-backup-share"
  private var clientId: String
  private let decoder = JSONDecoder()
  private var folder: String

  init(
    clientId: String,
    view: UIViewController? = nil,
    folder: String = "_PORTAL_MPC_DO_NOT_DELETE_"
  ) {
    self.api = HttpRequester(baseUrl: self.baseUrl)
    self.auth = GoogleAuth(config: GIDConfiguration(clientID: clientId), view: view)
    self.clientId = clientId
    self.folder = folder
  }

  public func delete(_ id: String) async throws -> Bool {
    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files/\(id)") {
      let _ = try await PortalRequests.delete(url, withBearerToken: accessToken)
      return true
    }

    throw URLError(.badURL)
  }

  private func getAccessToken() async -> String {
    return await self.auth.getAccessToken()
  }

  public func getIdForFilename(_ filename: String) async throws -> String {
    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    let query = "name='\(filename)'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    guard let query = query else {
      throw GDriveClientError.unableToBuildGDriveQuery
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files?corpora=user&q=\(query)") {
      let data = try await PortalRequests.get(url, withBearerToken: accessToken)
      let filesListResponse = try decoder.decode(GDriveFilesListResponse.self, from: data)

      if filesListResponse.files.count > 0 {
        return filesListResponse.files[0].id
      }

      throw GDriveClientError.noFileFound
    }

    throw URLError(.badURL)
  }

  public func read(_ id: String) async throws -> String {
    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files/\(id)?alt=media") {
      let data = try await PortalRequests.get(url, withBearerToken: accessToken)

      guard let fileContents = String(data: data, encoding: .utf8) else {
        throw GDriveClientError.unableToReadFileContents
      }

      return fileContents
    }

    throw URLError(.badURL)
  }

  public func validateOperations() async throws -> Bool {
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

  private func createFolder() async throws -> GDriveFile {
    let accessToken = await auth.getAccessToken()

    if let url = URL(string: "\(baseUrl)/drive/v3/files?ignoreDefaultVisibility=true") {
      let payload = GDriveFolderMetadata(
        mimeType: "application/vnd.google-apps.folder",
        name: self.folder,
        parents: ["root"]
      )
      let data = try await PortalRequests.post(url, withBearerToken: accessToken, andPayload: payload)
      let file = try decoder.decode(GDriveFile.self, from: data)

      return file
    }

    throw URLError(.badURL)
  }

  private func getOrCreateFolder() async throws -> GDriveFile {
    let accessToken = await auth.getAccessToken()
    if accessToken.isEmpty {
      throw GDriveClientError.userNotAuthenticated
    }

    guard let query = "name='\(folder)'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      throw GDriveClientError.unableToBuildGDriveQuery
    }

    if let url = URL(string: "\(baseUrl)/drive/v3/files?q=\(query)") {
      let data = try await PortalRequests.get(url, withBearerToken: accessToken)
      let filesListResponse = try decoder.decode(GDriveFilesListResponse.self, from: data)

      if filesListResponse.files.count > 0 {
        return filesListResponse.files[0]
      }

      let folder = try await createFolder()

      return folder
    }

    throw URLError(.badURL)
  }

  private func writeFile(_ filename: String, withContent: String, andAccessToken: String) async throws -> String {
    let folder = try await getOrCreateFolder()

    if let url = URL(string: "\(baseUrl)/upload/drive/v3/files?ignoreDefaultVisibility=true&uploadType=multipart") {
      let metadata = GDriveFileMetadata(name: filename, parents: [folder.id])
      let body = try self.buildMultipartFormData(
        withContent,
        withMetadata: metadata
      )

      let data = try await PortalRequests.postMultiPartData(
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

  private func buildMultipartFormData(_ content: String, withMetadata: GDriveFileMetadata) throws -> String {
    let metadataJSON = try JSONEncoder().encode(withMetadata)
    let metadataString = String(data: metadataJSON, encoding: .utf8)!
    let body = [
      "--\(boundary)\n",
      "Content-Type: application/json; charset=UTF-8\n\n",
      "\(metadataString)\n",
      "--\(boundary)\n",
      "Content-Type: text/plain\n\n",
      "\(content)\n",
      "--\(boundary)--",
    ]

    return body.joined(separator: "")
  }
}

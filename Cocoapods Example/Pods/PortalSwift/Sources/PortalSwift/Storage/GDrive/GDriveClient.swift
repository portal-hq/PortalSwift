//
//  GDriveClient.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn

struct GDriveDeleteResponse: Codable {
  let kind: String
}

struct GDriveFile: Codable {
  let kind: String
  let id: String
  let name: String
  let mimeType: String
}

struct GDriveFolderMetadata: Codable {
  let mimeType: String
  let name: String
  let parents: [String]
}

struct GDriveFileMetadata: Codable {
  let name: String
  let parents: [String]
}

struct GDriveFilesListResponse: Codable {
  let kind: String
  let incompleteSearch: Bool
  let files: [GDriveFile]
}

public enum GDriveClientError: Error {
  case userNotAuthenticated
}

private struct NoFileFoundError: Error {}

class GDriveClient {
  private var api: HttpRequester
  public var auth: GoogleAuth
  private var baseUrl: String = "https://www.googleapis.com"
  private var boundary: String = "portal-backup-share"
  private var clientId: String
  private var folder: String

  init(
    clientId: String,
    view: UIViewController,
    folder: String = "_PORTAL_MPC_DO_NOT_DELETE_"
  ) {
    self.api = HttpRequester(baseUrl: self.baseUrl)
    self.auth = GoogleAuth(config: GIDConfiguration(clientID: clientId), view: view)
    self.clientId = clientId
    self.folder = folder
  }

  public func delete(id: String, callback: @escaping (Result<Bool>) -> Void) {
    self.auth.getAccessToken { accessToken in
      if accessToken.error != nil {
        callback(Result(error: accessToken.error!))
        return
      } else if accessToken.data == "" {
        callback(Result(error: GDriveClientError.userNotAuthenticated))
        return
      }

      do {
        try self.api.delete(
          path: "/drive/v3/files/\(id)",
          headers: ["Authorization": "Bearer \(accessToken.data!)"],
          requestType: HttpRequestType.CustomRequest
        ) { (result: Result<String>) in
          if result.error != nil {
            callback(Result(error: result.error!))
            return
          }

          callback(Result(data: true))
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }

  private func getAccessToken(callback: @escaping (Result<String>) -> Void) {
    self.auth.getAccessToken { accessToken in
      callback(accessToken)
    }
  }

  public func getIdForFilename(filename: String, callback: @escaping (Result<String>) -> Void) throws {
    self.auth.getAccessToken { accessToken in
      let query = "name='\(filename)'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
      do {
        try self.api.get(
          path: "/drive/v3/files?corpora=user&q=\(query!)",
          headers: [
            "Accept": "application/json",
            "Authorization": "Bearer \(accessToken.data!)",
            "Content-Type": "application/json",
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (result: Result<GDriveFilesListResponse>) in
          if result.error != nil {
            callback(Result(error: result.error!))
            return
          }

          if result.data!.files.count > 0 {
            callback(Result(data: result.data!.files[0].id))
            return
          }

          callback(Result(error: NoFileFoundError()))
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }

  public func read(id: String, callback: @escaping (Result<String>) -> Void) {
    self.auth.getAccessToken { accessToken in
      do {
        try self.api.get(
          path: "/drive/v3/files/\(id)?alt=media",
          headers: [
            "Accept": "application/json",
            "Authorization": "Bearer \(accessToken.data!)",
            "Content-Type": "application/json",
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (result: Result<String>) in
          if result.error != nil {
            callback(Result(error: result.error!))
            return
          }

          callback(result)
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }

  public func write(filename: String, content: String, callback: @escaping (Result<String>) -> Void) throws {
    self.auth.getAccessToken { accessToken in
      if accessToken.error != nil {
        callback(Result(error: accessToken.error!))
        return
      }

      // Delete existing file
      do {
        try self.getIdForFilename(filename: filename) { (fileId: Result<String>) in
          if fileId.error != nil {
            if fileId.error is NoFileFoundError {
              print("[Portal.GDriveStorage] No existing file found. Skipping delete.")
              do {
                try self.writeFile(filename: filename, content: content, accessToken: accessToken.data!) { result in
                  callback(result)
                }
                return
              } catch {
                callback(Result(error: error))
                return
              }
            } else {
              callback(Result(error: fileId.error!))
              return
            }
          }

          let existingFileId = fileId.data!
          self.delete(id: existingFileId) { result in
            if result.error != nil {
              callback(Result(error: result.error!))
              return
            }

            do {
              try self.writeFile(filename: filename, content: content, accessToken: accessToken.data!) { (result: Result<String>) in
                callback(result)
              }
            } catch {
              callback(Result(error: error))
            }
          }
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }

  public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    let mockFileName = "portal_test.txt"
    let mockContent = "test_value"

    self.auth.getAccessToken { accessToken in
      if let error = accessToken.error {
        callback(Result(error: error))
        return
      }

      guard let accessToken = accessToken.data, !accessToken.isEmpty else {
        callback(Result(error: GDriveStorageError.unknownError))
        return
      }

      // Write
      do {
        try self.write(filename: mockFileName, content: mockContent) { writeResult in
          if let error = writeResult.error {
            callback(Result(error: error))
            return
          }

          // Read
          do {
            try self.getIdForFilename(filename: mockFileName) { fileIdResult in
              if let error = fileIdResult.error {
                callback(Result(error: error))
                return
              }

              guard let fileId = fileIdResult.data else {
                callback(Result(error: GDriveStorageError.unknownError))
                return
              }

              self.read(id: fileId) { readResult in
                if let error = readResult.error {
                  callback(Result(error: error))
                  return
                }

                guard let readData = readResult.data, readData == mockContent else {
                  callback(Result(error: GDriveStorageError.unknownError))
                  return
                }

                // Delete
                self.delete(id: fileId) { deleteResult in
                  if let error = deleteResult.error {
                    callback(Result(error: error))
                  } else {
                    callback(Result(data: true))
                  }
                }
              }
            }
          } catch {
            callback(Result(error: error))
          }
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }

  private func buildMultipartFormData(content: String, metadata: GDriveFileMetadata) throws -> String {
    let metadataJSON = try JSONEncoder().encode(metadata)
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

  private func createFolder(callback: @escaping (Result<GDriveFile>) -> Void) throws {
    self.auth.getAccessToken { accessToken in
      if accessToken.error != nil {
        callback(Result(error: accessToken.error!))
        return
      }

      do {
        let body = GDriveFolderMetadata(
          mimeType: "application/vnd.google-apps.folder",
          name: self.folder,
          parents: ["root"]
        )
        let bodyData = try JSONEncoder().encode(body)
        let bodyString = String(data: bodyData, encoding: .utf8)!

        try self.api.post(
          path: "/drive/v3/files?ignoreDefaultVisibility=true",
          body: [
            "name": body.name,
            "mimeType": body.mimeType,
            "parents": body.parents,
          ],
          headers: [
            "Accept": "application/json",
            "Authorization": "Bearer \(accessToken.data!)",
            "Content-Type": "application/json",
            "Content-Length": String(bodyString.count),
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (_: Result<GDriveFile>) in
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }

  private func getOrCreateFolder(callback: @escaping (Result<GDriveFile>) -> Void) {
    self.auth.getAccessToken { accessToken in
      if accessToken.error != nil {
        callback(Result(error: accessToken.error!))
        return
      }

      do {
        let query = "name='\(self.folder)'".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        try self.api.get(
          path: "/drive/v3/files?q=\(query!)",
          headers: [
            "Accept": "application/json",
            "Authorization": "Bearer \(accessToken.data!)",
            "Content-Type": "application/json",
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (result: Result<GDriveFilesListResponse>) in
          if result.error != nil {
            callback(Result(error: result.error!))
            return
          }

          do {
            if result.data!.files.count > 0 {
              callback(Result(data: result.data!.files[0]))
            } else {
              try self.createFolder { createdFolder in
                callback(createdFolder)
              }
            }
          } catch {
            callback(Result(error: error))
          }
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }

  private func writeFile(filename: String, content: String, accessToken: String, callback: @escaping (Result<String>) -> Void) throws {
    self.getOrCreateFolder { folder in
      if folder.error != nil {
        callback(Result(error: folder.error!))
        return
      }

      do {
        let metadata = GDriveFileMetadata(
          name: filename,
          parents: [folder.data!.id]
        )

        let body = try self.buildMultipartFormData(
          content: content,
          metadata: metadata
        )

        try self.api.post(
          path: "/upload/drive/v3/files?ignoreDefaultVisibility=true&uploadType=multipart",
          body: ["rawBody": body],
          headers: [
            "Authorization": "Bearer \(accessToken)",
            "Content-Type": "multipart/related; boundary=\(self.boundary)",
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (result: Result<GDriveFile>) in
          if result.error != nil {
            callback(Result(error: result.error!))
            return
          }

          callback(Result(data: result.data!.id))
        }
      } catch {
        callback(Result(error: error))
      }
    }
  }
}

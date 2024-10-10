import GoogleSignIn

struct GDriveDeleteResponse: Codable {
  let kind: String
}

public struct GDriveFile: Codable {
  let kind: String
  let id: String
  let name: String
  let mimeType: String
}

struct GDriveFolderMetadata: Codable, Equatable {
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

struct GDriveNoFileFoundError: Error {}

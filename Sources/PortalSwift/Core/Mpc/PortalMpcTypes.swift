public typealias PortalMpcGenerateResponse = [String: PortalMpcGeneratedShare]

public struct PortalMpcGeneratedShare: Codable {
  public let id: String
  public let share: String
}

/// A MPC share that includes a variable number of fields, depending on the MPC version being used
/// GG18 shares will only contain: bks, pubkey, and share
/// CGGMP shares will contain all fields except: pubkey.
public struct MpcShare: Codable {
  public var allY: PartialPublicKey?
  public var backupSharePairId: String?
  public var bks: Berkhoffs?
  public var clientId: String
  public var p: String
  public var partialPubkey: PartialPublicKey?
  public var pederson: Pederssens?
  public var pubkey: PublicKey?
  public var q: String
  public var share: String
  public var signingSharePairId: String?
  public var ssid: String
}

/// In the bks dictionary for an MPC share, Berkhoff is the value.
public struct Berkhoff: Codable {
  public var X: String
  public var Rank: Int
}

/// A partial public key for client and server (x, y)
public struct PartialPublicKey: Codable {
  public var client: PublicKey?
  public var server: PublicKey?
}

/// A berhkoff coefficient mapping for client and server (x, rank)
public struct Berkhoffs: Codable {
  public var client: Berkhoff?
  public var server: Berkhoff?
}

public struct Pederssen: Codable {
  public var n: String?
  public var s: String?
  public var t: String?
}

public struct Pederssens: Codable {
  public var client: Pederssen?
  public var server: Pederssen?
}

/// A public key's coordinates (x, y).
public struct PublicKey: Codable {
  public var X: String?
  public var Y: String?
}

struct DecryptResult: Codable {
  public var data: DecryptData?
  public var error: PortalError
}

struct DecryptData: Codable {
  public var plaintext: String
}

/// The response from encrypting.
struct EncryptDataWithPassword: Codable {
  public var cipherText: String
}

struct EncryptResultWithPassword: Codable {
  public var data: EncryptDataWithPassword?
  public var error: PortalError
}

/// The response from encrypting.
public struct EncryptData: Codable {
  public var key: String
  public var cipherText: String
}

struct EncryptResult: Codable {
  public var data: EncryptData?
  public var error: PortalError
}

/// The response from fetching the client.
public struct ClientResult: Codable {
  public var data: Client?
  public var error: PortalError
}

/// The response from fetching the client.
public struct EjectResult: Codable {
  public var privateKey: String
  public var error: PortalError
}

/// The data for GenerateResult.
public struct GenerateData: Codable {
  public var address: String
  public var dkgResult: MpcShare?
}

/// The response from generating.
struct GenerateResult: Codable {
  public var data: GenerateData?
  public var error: PortalError
}

/// The data for RotateResult.
public struct RotateData: Codable {
  public var address: String
  public var dkgResult: MpcShare
}

/// The response from rotating.
struct RotateResult: Codable {
  public var data: RotateData?
  public var error: PortalError
}

/// The data for SignResult.
public struct SignData: Codable {
  public var R: String
  public var S: String
}

/// The response from signing.
public struct SignResult: Codable {
  public var data: String?
  public var error: PortalError
}

public struct MpcStatus {
  public var status: MpcStatuses
  public var done: Bool
}

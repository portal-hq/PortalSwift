public struct PortalMpcBackupResponse {
  public let cipherText: String
  public let shareIds: [String]
}

public struct FormatShareResponse: Codable {
  let data: PortalMpcGenerateResponse?
  let error: PortalError?
}

public typealias PortalMpcGenerateResponse = [String: PortalMpcGeneratedShare]

public struct PortalMpcGeneratedShare: Codable, Equatable {
  public let id: String
  public let share: String

  public static func == (lhs: PortalMpcGeneratedShare, rhs: PortalMpcGeneratedShare) -> Bool {
    return lhs.id == rhs.id && lhs.share == rhs.share
  }
}

/// A MPC share that includes the share and optionally a backupSharePairId and a signingSharePairId.
public struct MpcShare: Codable, Equatable {
  public let clientId: String
  public let backupSharePairId: String?
  public let signingSharePairId: String?
  public let share: String
  public let ssid: String
  public let pubkey: PublicKey?
  public let partialPubkey: PartialPublicKey?
  public let allY: AllY?
  public let p: String?
  public let q: String?
  public let pederson: Pederson?
  public let bks: BKS?

  // Additional fields to handle different SDK formats
  public let partialPublicKey: PartialPublicKey? // For Kotlin SDK
  public let partialPubKey: [PublicKey]? // For Web SDK

  public struct PublicKey: Codable, Equatable {
    public let X: String
    public let Y: String
  }

  public struct PartialPublicKey: Codable, Equatable {
    public let client: PublicKey
    public let server: PublicKey
  }

  public struct AllY: Codable, Equatable {
    public let client: PublicKey
    public let server: PublicKey
  }

  public struct Pederson: Codable, Equatable {
    public let client: PedersonData
    public let server: PedersonData

    public struct PedersonData: Codable, Equatable {
      public let n: String
      public let s: String
      public let t: String
    }
  }

  public struct BKS: Codable, Equatable {
    public let client: BKSData
    public let server: BKSData

    public struct BKSData: Codable, Equatable {
      public let X: String
      public let Rank: Int
    }
  }

  public static func == (lhs: MpcShare, rhs: MpcShare) -> Bool {
    return lhs.signingSharePairId == rhs.signingSharePairId &&
      lhs.backupSharePairId == rhs.backupSharePairId &&
      lhs.share == rhs.share
  }

  // Custom initializer to handle different SDK formats
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    clientId = try container.decodeIfPresent(String.self, forKey: .clientId) ?? ""
    backupSharePairId = try container.decodeIfPresent(String.self, forKey: .backupSharePairId)
    signingSharePairId = try container.decodeIfPresent(String.self, forKey: .signingSharePairId)
    share = try container.decode(String.self, forKey: .share)
    ssid = try container.decode(String.self, forKey: .ssid)
    pubkey = try container.decodeIfPresent(PublicKey.self, forKey: .pubkey)
    partialPubkey = try container.decodeIfPresent(PartialPublicKey.self, forKey: .partialPubkey)
    allY = try container.decodeIfPresent(AllY.self, forKey: .allY)
    p = try container.decodeIfPresent(String.self, forKey: .p)
    q = try container.decodeIfPresent(String.self, forKey: .q)
    pederson = try container.decodeIfPresent(Pederson.self, forKey: .pederson)
    bks = try container.decodeIfPresent(BKS.self, forKey: .bks)

    // Handle Kotlin SDK format
    partialPublicKey = try container.decodeIfPresent(PartialPublicKey.self, forKey: .partialPublicKey)

    // Handle Web SDK format
    partialPubKey = try container.decodeIfPresent([PublicKey].self, forKey: .partialPubKey)
  }
}

struct DecryptResult: Codable {
  public var data: DecryptData?
  public var error: PortalError?
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
  public var error: PortalError?
}

/// The response from encrypting.
public struct EncryptData: Codable, Equatable {
  public var key: String
  public var cipherText: String
}

struct EncryptResult: Codable {
  public var data: EncryptData?
  public var error: PortalError?
}

/// The response from fetching the client.
public struct ClientResult: Codable {
  public var data: Client?
  public var error: PortalError
}

/// The response from fetching the client.
public struct EjectResult: Codable {
  public var privateKey: String?
  public var error: PortalError?
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
  public var share: MpcShare
}

/// The response from rotating.
struct RotateResult: Codable {
  public var data: RotateData?
  public var error: PortalError?
}

/// The data for SignResult.
public struct SignData: Codable {
  public var R: String
  public var S: String
}

/// The response from signing.
public struct SignResult: Codable {
  public var data: String?
  public var error: PortalError?
}

public struct MpcStatus {
  public var status: MpcStatuses
  public var done: Bool
}

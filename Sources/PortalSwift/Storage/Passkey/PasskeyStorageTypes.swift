public struct PasskeyLoginReadResponse: Codable {
  let encryptionKey: String
}

public struct WebAuthnRegistrationOptions: Codable {
  let options: RegistrationOptions
  let sessionId: String
}

public struct RegistrationOptions: Codable {
  let publicKey: PublicKeyOptions
}

public struct PublicKeyOptions: Codable {
  let rp: RelyingParty
  let user: User
  let challenge: String
  let pubKeyCredParams: [CredentialParameter]?
  let timeout: Int
  let authenticatorSelection: AuthenticatorSelection?
  let attestation: String?
}

public struct RelyingParty: Codable {
  let name: String
  let id: String
}

public struct User: Codable {
  let name: String
  let displayName: String
  let id: String
}

public struct CredentialParameter: Codable {
  let type: String?
  let alg: Int?
}

struct AuthenticatorSelection: Codable {
  let authenticatorAttachment: String?
  let requireResidentKey: Bool?
  let residentKey: String?
  let userVerification: String?
}

public struct WebAuthnAuthenticationOption: Codable {
  let options: AuthenticationOptions
  let sessionId: String
}

public struct AuthenticationOptions: Codable {
  let publicKey: PublicKey

  struct PublicKey: Codable {
    let challenge: String
    let timeout: Int
    let rpId: String
    let allowCredentials: [Credential]
    let userVerification: String
  }

  struct Credential: Codable {
    let type: String
    let id: String?
  }
}

public struct PasskeyStatusResponse: Codable {
  let status: PasskeyStatus
}

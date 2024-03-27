struct PasskeyLoginReadResponse: Codable {
  let encryptionKey: String
}

struct WebAuthnRegistrationOptions: Codable {
  let options: RegistrationOptions
  let sessionId: String
}

struct RegistrationOptions: Codable {
  let publicKey: PublicKeyOptions
}

struct PublicKeyOptions: Codable {
  let rp: RelyingParty
  let user: User
  let challenge: String
  let pubKeyCredParams: [CredentialParameter]?
  let timeout: Int
  let authenticatorSelection: AuthenticatorSelection?
  let attestation: String?
}

struct RelyingParty: Codable {
  let name: String
  let id: String
}

struct User: Codable {
  let name: String
  let displayName: String
  let id: String
}

struct CredentialParameter: Codable {
  let type: String?
  let alg: Int?
}

struct AuthenticatorSelection: Codable {
  let authenticatorAttachment: String?
  let requireResidentKey: Bool?
  let residentKey: String?
  let userVerification: String?
}

struct WebAuthnAuthenticationOption: Codable {
  let options: AuthenticationOptions
  let sessionId: String
}

struct AuthenticationOptions: Codable {
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

struct PasskeyStatusResponse: Codable {
  let status: PasskeyStatus
}

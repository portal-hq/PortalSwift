//
//  PortalAuthWireTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

// Wire types for the Client Auth endpoints.
//
// Internal by design: each is mapped onto a public type before it leaves `PortalAuth`, so a
// backend field rename never reaches a host's source. Every response field is optional
// because the backend omits keys it has nothing to say about (a provider that is not enabled,
// client metadata it did not resolve), and an omitted key must read as "absent", never as a
// decoding failure.

// MARK: - Persistence

/// What `PortalAuth` persists for a signed-in user, keyed by `authEnvironmentId`.
///
/// Only two fields: the client session token and the end user it belongs to. `clientId` is
/// unknown at persist time on the TOTP path and is not needed to restore a session, so it is
/// deliberately left out; hosts that need it read it from the `AuthenticatedResult`.
struct PersistedSession: Equatable {
  /// The bearer the SDK presents to Portal-owned hosts. Never logged.
  let clientSessionToken: String
  /// The end user the token was issued for; safe to log.
  let endUserId: String
}

// MARK: - Envelope

/// Client Auth success responses are enveloped as `{ "data": … }`.
///
/// `data` is optional so `{ "data": null }` and a body without the key both decode to `nil`
/// and are reported by the transport as `PortalAuthError.malformedResponse(path, nil)`,
/// rather than one of them failing inside `JSONDecoder` with a less useful error.
struct AuthEnvelope<T: Decodable>: Decodable {
  let data: T?
}

// MARK: - Responses

/// Raw form of `AuthMethodsResult`.
///
/// `allowedAuthMethods` is read as strings so a method this SDK version does not know about
/// can be dropped by the caller rather than failing the whole decode.
struct AuthMethodsResponse: Decodable {
  let allowedAuthMethods: [String]?
  let autoCreateWallet: Bool?
}

/// `{ google, apple }`. A key is present only for a provider the auth environment has enabled.
struct OAuthUrlsResponse: Decodable {
  let google: String?
  let apple: String?
}

/// Returned by both grant-exchange endpoints (`/magic-links/validations`, `/oauth/tokens`).
///
/// Either `clientSessionToken` is set (the login is done) or `userJwt` is (a TOTP step is
/// required). That either/or is the entire branching logic of the flow; `totpLink` rides
/// along on first-time enrollment and embeds the TOTP secret, so it is never logged.
struct AuthGrantValidationResponse: Decodable {
  let endUserId: String?
  let clientId: String?
  let clientSessionToken: String?
  let isAccountAbstracted: Bool?
  let userJwt: String?
  let totpLink: String?
}

/// Returned by `POST /totps/validations`.
///
/// Carries no `endUserId` — the session still needs one, so `PortalAuth.verifyTotp` reads it
/// from the `userJwt`'s claims instead.
struct TotpValidationResponse: Decodable {
  let clientId: String?
  let clientSessionToken: String?
  let isAccountAbstracted: Bool?
}

/// A `TotpValidationResponse` the transport has already checked.
///
/// The only difference is that `clientSessionToken` is non-optional, and that is the point:
/// it puts the "a validated TOTP always names a session" rule in the type rather than in a
/// caller's comment. An empty token is the one value that would fail *quietly* — written to
/// storage, then surfaced far away as an unrestorable session on the next launch — so the
/// transport rejects it before this value can exist.
struct TotpValidation {
  let clientId: String?
  let clientSessionToken: String
  let isAccountAbstracted: Bool?
}

// MARK: - Request bodies

/// Body of `POST /magic-links`.
///
/// `isAccountAbstracted` is omitted from the JSON when `nil` (the synthesized encoder uses
/// `encodeIfPresent`): omitting it inherits the organisation's default, whereas sending
/// `false` would pin the client to a non-abstracted one. `Codable` rather than `Encodable`
/// because `PortalAPIRequest.payload` is typed `(any Codable)?`.
struct SendMagicLinkRequest: Codable {
  let email: String
  let redirectUrl: String
  let fromEmail: String
  let templateId: String
  let isAccountAbstracted: Bool?
}

/// Body of `POST /magic-links/validations` and `POST /oauth/tokens`.
struct GrantTokenRequest: Codable {
  let token: String
}

/// Body of `POST /totps/validations`. The `userJwt` travels as the bearer, not in the body.
struct TotpCodeRequest: Codable {
  let code: String
}

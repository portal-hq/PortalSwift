//
//  PasskeyStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.

import AuthenticationServices
import os
import UIKit

@available(iOS 16.0, *)
public class PasskeyAuth: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
  // Current active UI Window to present passkey modal too
  var authenticationAnchor: ASPresentationAnchor?
  // These need to be sent back to the server as part of the registration and authentication ceremonies
  var attestation: String?
  var assertion: String?
  // The domain of our relying party server.
  private var domain = "trustless.portalhq.io"
  var authorizationCompletion: AuthorizationCompletion?
  var registrationCompletion: RegistrationCompletion?
  deinit {
    print("PasskeyAuth is being deallocated")
  }

  init(domain: String? = "trustless.portalhq.io") {
    self.domain = domain ?? "trustless.portalhq.io"
  }

  /// Signs a user up using passkeys to the relying party domain
  /// - Parameters:
  ///   - userName: username harded coded as "Backup"
  ///   - userId: UserId from the 'begin/registration' endpoint
  ///   - challenge: Data object to sign to verify passkey registration
  ///   - anchor: window of current UI
  func signUpWith(options: RegistrationOptions, anchor: ASPresentationAnchor) {
    self.authenticationAnchor = anchor
    let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

    let challenge = options.publicKey.challenge.decodeBase64Url()!
    let userId = Data(options.publicKey.user.id.utf8)
    let username = options.publicKey.user.displayName

    let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: username, userID: userId)

    if let attestation = options.publicKey.attestation {
      registrationRequest.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(rawValue: attestation)
    }

    // Check if the webapp requires user verification (see https://docs.hanko.io/guides/userverification)
    if let userVerification = options.publicKey.authenticatorSelection?.userVerification {
      registrationRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: userVerification)
    }

    // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
    let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
    authController.delegate = self
    authController.presentationContextProvider = self
    authController.performRequests()
  }

  func signInWith(anchor: ASPresentationAnchor, options: AuthenticationOptions, preferImmediatelyAvailableCredentials: Bool) {
    self.authenticationAnchor = anchor
    let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
    let challenge = options.publicKey.challenge.decodeBase64Url()!

    let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

    // Pass in any mix of supported sign-in request types.
    let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
    authController.delegate = self
    authController.presentationContextProvider = self

    if preferImmediatelyAvailableCredentials {
      // If credentials are available, presents a modal sign-in sheet.
      // If there are no locally saved credentials, no UI appears and
      // the system passes ASAuthorizationError.Code.canceled to call
      authController.performRequests(options: .preferImmediatelyAvailableCredentials)
    } else {
      // If credentials are available, presents a modal sign-in sheet.
      // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
      // passkey from a nearby device.
      authController.performRequests()
    }
  }

  public func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
    let logger = Logger()
    guard let authorizationError = error as? ASAuthorizationError else {
      logger.error("Unexpected authorization error: \(error.localizedDescription)")
      return
    }

    if authorizationError.code == .canceled {
      // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
      // This is a good time to show a traditional login form, or ask the user to create an account.
      logger.log("Request canceled.")
    } else {
      // Another ASAuthorization error.
      // Note: The userInfo dictionary contains useful information.
      logger.error("Error: \((error as NSError).userInfo)")
    }
  }

  public func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    return self.authenticationAnchor!
  }

  public func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    let logger = Logger()
    switch authorization.credential {
    case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
      logger.log("A new passkey was registered: \(credentialRegistration)")

      guard let attestationObject = credentialRegistration.rawAttestationObject else { return }
      let clientDataJSON = credentialRegistration.rawClientDataJSON
      let credentialID = credentialRegistration.credentialID

      // Build the attestaion object
      let payload = ["rawId": credentialID.toBase64Url(), // Base64
                     "id": self.base64URLEncode(credentialRegistration.credentialID), // Base64URL
                     "authenticatorAttachment": "cross-platform", // Optional parameter
                     "clientExtensionResults": [String: Any](), // Optional parameter
                     "type": "public-key",
                     "response": [
                       "attestationObject": attestationObject.toBase64Url(),
                       "clientDataJSON": clientDataJSON.toBase64Url(),
                     ]] as [String: Any]

      if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
        guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
        self.attestation = payloadJSONText
        self.registrationCompletion!(self.attestation)
      }

    case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
      logger.log("A passkey was used to sign in: \(credentialAssertion)")

      guard let signature = credentialAssertion.signature else {
        print("Missing signature")
        return
      }
      guard let authenticatorData = credentialAssertion.rawAuthenticatorData else {
        print("Missing authenticatorData")
        return
      }
      guard let userID = credentialAssertion.userID else {
        print("Missing userID")
        return
      }
      let clientDataJSON = credentialAssertion.rawClientDataJSON
      let credentialId = credentialAssertion.credentialID

      let payload = ["rawId": credentialId.toBase64Url(), // Base64
                     "id": self.base64URLEncode(credentialId), // Binary
                     "authenticatorAttachment": "cross-platform", // Optional
                     "clientExtensionResults": [String: Any](), // Optional
                     "type": "public-key",
                     "response": [
                       "clientDataJSON": clientDataJSON.toBase64Url(),
                       "authenticatorData": authenticatorData.toBase64Url(),
                       "signature": signature.toBase64Url(),
                       "userHandle": self.base64URLEncode(userID),
                     ]] as [String: Any]

      if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
        guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
        self.assertion = payloadJSONText
        self.authorizationCompletion!(self.assertion)
      }

    default:
      fatalError("Received unknown authorization type.")
    }
  }

  func base64URLEncode(_ data: Data) -> String {
    let base64 = data.base64EncodedString()
    let base64URL = base64
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    return base64URL
  }
}

extension String {
  func decodeBase64Url() -> Data? {
    var base64 = self
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    if base64.count % 4 != 0 {
      base64.append(String(repeating: "=", count: 4 - base64.count % 4))
    }
    return Data(base64Encoded: base64)
  }
}

extension Data {
  func toBase64Url() -> String {
    return self.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }
}

public typealias AuthorizationCompletion = (_ assertion: String?) -> Void

public typealias RegistrationCompletion = (_ attestation: String?) -> Void

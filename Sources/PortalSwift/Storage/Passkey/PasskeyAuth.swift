//
//  PasskeyStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.

import AuthenticationServices
import os
import SwiftUI

@available(iOS 16.0, *)
public class PasskeyManager: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
  var authenticationAnchor: ASPresentationAnchor?
  var attestation: String?
  var assertion: String?
  private var domain = "c2c4-2600-4041-550c-1b00-45c9-8525-9b76-ca37.ngrok-free.app"
  override public init() {}

  public func signUpWith(userName: String, userId: Data, challenge: Data, anchor: ASPresentationAnchor) {
    self.authenticationAnchor = anchor
    let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
    let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: userName, userID: userId)

    // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
    let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
    authController.delegate = self
    authController.presentationContextProvider = self
    authController.performRequests()
  }

  public func signInWith(anchor _: ASPresentationAnchor, challenge: Data, preferImmediatelyAvailableCredentials: Bool) {
//    UIApplication.shared.authenticationAnchor = anchor
    let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
    let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

    // Also allow the user to use a saved password, if they have one.
    let passwordCredentialProvider = ASAuthorizationPasswordProvider()
    let passwordRequest = passwordCredentialProvider.createRequest()

    // Pass in any mix of supported sign-in request types.
    let authController = ASAuthorizationController(authorizationRequests: [assertionRequest, passwordRequest])
    authController.delegate = self
    authController.presentationContextProvider = self

    if preferImmediatelyAvailableCredentials {
      // If credentials are available, presents a modal sign-in sheet.
      // If there are no locally saved credentials, no UI appears and
      // the system passes ASAuthorizationError.Code.canceled to call
      // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
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

//    Alert.generic(viewController: controller, message: "Sign up", error: error as NSError)
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
      let payload = ["rawId": credentialID.base64EncodedString(), // Base64
                     "id": self.base64URLEncode(credentialRegistration.credentialID), // Base64URL
                     "authenticatorAttachment": "platform", // Optional parameter
                     "clientExtensionResults": [String: Any](), // Optional parameter
                     "type": "public-key",
                     "response": [
                       "attestationObject": attestationObject.base64EncodedString(),
                       "clientDataJSON": clientDataJSON.base64EncodedString(),
                     ]] as [String: Any]

      if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
        guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
        self.attestation = payloadJSONText
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

      let payload = ["rawId": credentialId.base64EncodedString(), // Base64
                     "id": self.base64URLEncode(credentialId), // Binary
                     "authenticatorAttachment": "platform", // Optional
                     "clientExtensionResults": [String: Any](), // Optional
                     "type": "public-key",
                     "response": [
                       "clientDataJSON": clientDataJSON.base64EncodedString(),
                       "authenticatorData": authenticatorData.base64EncodedString(),
                       "signature": signature.base64EncodedString(),
                       "userHandle": self.base64URLEncode(userID),
                     ]] as [String: Any]

      if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
        guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
        self.assertion = payloadJSONText
      }

    case let passwordCredential as ASPasswordCredential:
      logger.log("A password was provided: \(passwordCredential)")
      // Handle a case user choose to identify with password instead of passkeys
      // Verify the username and password with your service

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

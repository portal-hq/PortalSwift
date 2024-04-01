//
//  File.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

@available(iOS 16, *)
class MockPasskeyAuth: PasskeyAuth {
  override func signUpWith(_: RegistrationOptions) {
    self.continuation?.resume(returning: MockConstants.mockPasskeyAttestation)
  }

  override func signInWith(_: AuthenticationOptions, preferImmediatelyAvailableCredentials _: Bool) {
    self.continuation?.resume(returning: MockConstants.mockPasskeyAssertion)
  }
}

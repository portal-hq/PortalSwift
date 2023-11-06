//
//  MobileStorageAdapter.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/29/23.
//

import Foundation

public class MobileStorageAdapter {
  public func getAddress() throws -> String {
    fatalError("Subclass must override getAddress()")
  }

  /// Retrieve the signing share stored in the client's keychain.
  /// - Returns: The client's signing share.
  public func getSigningShare() throws -> String {
    fatalError("Subclass must override getSigningShare()")
  }

  /// Sets the address in the client's keychain.
  /// - Parameter address: The public address of the client's wallet.
  public func setAddress(address _: String, completion _: (Result<OSStatus>) -> Void) {
    fatalError("Subclass must override setAddress()")
  }

  /// Sets the signing share in the client's keychain.
  /// - Parameter signingShare: A dkg object.
  public func setSigningShare(signingShare _: String, completion _: (Result<OSStatus>) -> Void) {
    fatalError("Subclass must override setSigningShare()")
  }

  /// Deletes the address stored in the client's keychain.
  /// - Returns: The client's address.
  public func deleteAddress() throws {
    fatalError("Subclass must override deleteAddress()")
  }

  /// Deletes the signing share stored in the client's keychain.
  /// - Returns: The client's signing share.
  public func deleteSigningShare() throws {
    fatalError("Subclass must override deleteSigningShare()")
  }
}

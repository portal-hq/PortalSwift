//
//  MockMpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation

enum MockMobileWrapperError: Error {
  case unableToEncodeData
}

public class MockMobileWrapper: Mobile {
  public init() {}

  public func MobileGenerateEd25519(_: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileGenerateSecp256k1(_: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileBackupEd25519(_: String, _: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileBackupSecp256k1(_: String, _: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileRecoverSigningEd25519(_: String, _: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileRecoverSigningSecp256k1(_: String, _: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileGenerate(_: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileBackup(_: String, _: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileRecoverSigning(_: String, _: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileRecoverBackup(_: String, _: String, _: String, _: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      do {
        try continuation.resume(returning: MockConstants.mockRotateResult)
      } catch {
        continuation.resume(returning: "")
      }
    }
    return result
  }

  public func MobileEncryptWithPassword(data _: String, password _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      continuation.resume(returning: MockConstants.mockEncryptWithPasswordResult)
    }
    return result
  }

  public func MobileDecryptWithPassword(_: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      continuation.resume(returning: MockConstants.mockDecryptResult)
    }
    return result
  }

  public func MobileDecrypt(_: String, _: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      continuation.resume(returning: MockConstants.mockDecryptResult)
    }
    return result
  }

  public func MobileEncrypt(_: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      continuation.resume(returning: MockConstants.mockEncryptResult)
    }
    return result
  }

  public func MobileGetMe(_: String, _: String) -> String {
    do {
      let clientResponse = MockConstants.mockClient
      let clientResponseData = try JSONEncoder().encode(clientResponse)
      guard let clientResponseString = String(data: clientResponseData, encoding: .utf8) else {
        throw MockMobileWrapperError.unableToEncodeData
      }

      return clientResponseString
    } catch {
      return ""
    }
  }

  public func MobileGetVersion() -> String {
    return "4.0.1"
  }

  public func MobileSign(_: String?, _: String?, _: String?, _ method: String?, _: String?, _: String?, _: String?, _: String?) -> String {
    if method == PortalRequestMethod.eth_sendTransaction.rawValue {
      return MockConstants.mockTransactionHashResponse
    }
    return MockConstants.mockSignatureResponse
  }

  public func MobileEjectWalletAndDiscontinueMPCSecp265K1(_: String, _: String) -> String {
    return MockConstants.mockEip155EjectResponse
  }

    public func MobileEjectWalletAndDiscontinueMPCEd25519(_ clientDkgCipherText: String, _ serverDkgCipherText: String) async -> String {
        return MockConstants.mockSolonaEjectResponse
    }
}

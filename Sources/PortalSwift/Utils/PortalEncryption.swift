import Foundation

public protocol PortalEncryptionProtocol {
  func decrypt(_ value: String, withPrivateKey: String) async throws -> String
  func decrypt(_ value: String, withPassword: String) async throws -> String
  func encrypt(_ value: String) async throws -> EncryptData
  func encrypt(_ value: String, withPassword: String) async throws -> String
}

public class PortalEncryption: PortalEncryptionProtocol {
  public let decoder = JSONDecoder()
  private let mobile: Mobile

  public init(binary: Mobile? = nil) {
    self.mobile = binary ?? MobileWrapper()
  }

  public func decrypt(_ value: String, withPrivateKey: String) async throws -> String {
    let decryptedValue = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
      Task {
        do {
          let decryptedValue = await mobile.MobileDecrypt(withPrivateKey, value)
          guard let decryptedData = decryptedValue.data(using: .utf8) else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to parse decryption result."))
            return
          }
          let decryptResult = try decoder.decode(DecryptResult.self, from: decryptedData)

          if decryptResult.error.code > 0 {
            continuation.resume(throwing: PortalMpcError(decryptResult.error))
            return
          }

          guard let decryptedShare = decryptResult.data?.plaintext else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to get plaintext result."))
            return
          }

          continuation.resume(returning: decryptedShare)
        } catch {
          continuation.resume(throwing: error)
          return
        }
      }
    }

    return decryptedValue
  }

  public func decrypt(_ value: String, withPassword: String) async throws -> String {
    let decryptedValue = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
      Task {
        do {
          let decryptedValue = await mobile.MobileDecryptWithPassword(withPassword, value)
          guard let decryptedData = decryptedValue.data(using: .utf8) else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to parse decryption result."))
            return
          }
          let decryptResult = try decoder.decode(DecryptResult.self, from: decryptedData)

          if decryptResult.error.code > 0 {
            continuation.resume(throwing: PortalMpcError(decryptResult.error))
            return
          }

          guard let decryptedShare = decryptResult.data?.plaintext else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to get plaintext result."))
            return
          }

          continuation.resume(returning: decryptedShare)
        } catch {
          continuation.resume(throwing: error)
          return
        }
      }
    }

    return decryptedValue
  }

  public func encrypt(_ value: String) async throws -> EncryptData {
    let encryptData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<EncryptData, Error>) in
      Task {
        do {
          let encryptedValue = await mobile.MobileEncrypt(value)
          guard let encryptedData = encryptedValue.data(using: .utf8) else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to parse encryption result."))
            return
          }
          let encryptResult = try decoder.decode(EncryptResult.self, from: encryptedData)

          if encryptResult.error.code > 0 {
            continuation.resume(throwing: PortalMpcError(encryptResult.error))
            return
          }

          guard let encryptData = encryptResult.data else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to get encrypt data."))
            return
          }

          continuation.resume(returning: encryptData)
        } catch {
          continuation.resume(throwing: error)
          return
        }
      }
    }

    return encryptData
  }

  public func encrypt(_ value: String, withPassword: String) async throws -> String {
    let encryptData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
      Task {
        do {
          let encryptedValue = await mobile.MobileEncryptWithPassword(data: value, password: withPassword)
          guard let encryptedData = encryptedValue.data(using: .utf8) else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to parse encryption result."))
            return
          }
          let encryptResult = try decoder.decode(EncryptResultWithPassword.self, from: encryptedData)

          if encryptResult.error.code > 0 {
            continuation.resume(throwing: PortalMpcError(encryptResult.error))
            return
          }

          guard let encryptData = encryptResult.data else {
            continuation.resume(throwing: MpcError.unexpectedErrorOnDecrypt("Unable to get encrypt data."))
            return
          }

          continuation.resume(returning: encryptData.cipherText)
        } catch {
          continuation.resume(throwing: error)
          return
        }
      }
    }

    return encryptData
  }
}

public enum PortalEncryptionError: LocalizedError {
  case unableToEncodeData
}

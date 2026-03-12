//
//  PresignatureManager.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

struct PresignRetryConfig {
  let maxAttempts: Int
  let baseDelayNs: UInt64
  let multiplier: Double
  let maxDelayNs: UInt64

  static let `default` = PresignRetryConfig(
    maxAttempts: 3,
    baseDelayNs: 2_000_000_000,
    multiplier: 2.0,
    maxDelayNs: 300_000_000_000
  )

  static let fast = PresignRetryConfig(
    maxAttempts: 6,
    baseDelayNs: 1_000_000,
    multiplier: 2.0,
    maxDelayNs: 10_000_000
  )
}

public protocol PresignatureSource: AnyObject {
  func consumePresignature(forCurve curve: PortalCurve) async -> PresignatureEntry?
}

class PresignatureManager: PresignatureSource {
  private let apiKey: String
  private let mpcHost: String
  private let binary: Mobile
  private weak var keychain: PortalKeychainProtocol?
  private let maxPresignaturesPerCurve: [PresignatureSupportedCurve: Int]
  private let featureFlags: FeatureFlags?
  private let retryConfig: PresignRetryConfig

  private let fillTasks = ThreadSafeDictionary<String, Task<Void, Never>>()
  private let guard_ = PresignatureGuard()
  private let logger = PortalLogger.shared

  init(
    apiKey: String,
    mpcHost: String,
    binary: Mobile,
    keychain: PortalKeychainProtocol,
    maxPresignaturesPerCurve: [PresignatureSupportedCurve: Int],
    featureFlags: FeatureFlags?,
    retryConfig: PresignRetryConfig = .default
  ) {
    self.apiKey = apiKey
    self.mpcHost = mpcHost
    self.binary = binary
    self.keychain = keychain
    self.maxPresignaturesPerCurve = maxPresignaturesPerCurve
    self.featureFlags = featureFlags
    self.retryConfig = retryConfig
  }

  // MARK: - Public

  func initializeBuffers() {
    guard featureFlags?.usePresignatures == true else { return }

    logger.info("[PresignatureManager] Initializing presignature buffers for curves: \(PresignatureSupportedCurve.allCases.map(\.rawValue))")

    cancelAllFillTasks()

    for curve in PresignatureSupportedCurve.allCases {
      fillTasks[curve.rawValue] = Task { [weak self] in
        await self?.fillBuffer(curve: curve)
      }
    }
  }

  public func consumePresignature(forCurve curve: PortalCurve) async -> PresignatureEntry? {
    guard let supportedCurve = PresignatureSupportedCurve.allCases.first(where: { $0.portalCurve == curve }) else {
      logger.debug("[PresignatureManager] Curve \(curve.rawValue) is not supported for presignatures")
      return nil
    }

    guard let keychain else {
      logger.error("[PresignatureManager] Keychain deallocated, cannot consume presignature for \(supportedCurve.rawValue)")
      return nil
    }

    let entry = await guard_.pop(keychain: keychain, curve: supportedCurve.rawValue)

    if let entry {
      logger.debug("[PresignatureManager] Consumed presignature \(entry.id) for \(supportedCurve.rawValue), triggering refill")
      fillTasks[supportedCurve.rawValue] = Task { [weak self] in
        await self?.fillBuffer(curve: supportedCurve)
      }
    } else {
      logger.debug("[PresignatureManager] No presignatures available for \(supportedCurve.rawValue), falling back to normal sign")
    }

    return entry
  }

  func deleteAll() async {
    logger.info("[PresignatureManager] Deleting all presignatures")

    cancelAllFillTasks()

    guard let keychain else {
      logger.error("[PresignatureManager] Keychain deallocated, cannot delete presignatures")
      return
    }

    for curve in PresignatureSupportedCurve.allCases {
      do {
        try await keychain.deletePresignatures(curve.rawValue)
      } catch {
        logger.error("[PresignatureManager] Failed to delete presignatures for \(curve.rawValue): \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Private

  private func maxForCurve(_ curve: PresignatureSupportedCurve) -> Int {
    maxPresignaturesPerCurve[curve] ?? 0
  }

  private func preSign(curve: PresignatureSupportedCurve) async -> PresignatureEntry? {
    guard let keychain else {
      logger.error("[PresignatureManager] Keychain deallocated, cannot presign for \(curve.rawValue)")
      return nil
    }

    for attempt in 0 ..< retryConfig.maxAttempts {
      guard !Task.isCancelled else {
        logger.debug("[PresignatureManager] Presign cancelled for \(curve.rawValue)")
        return nil
      }
      do {
        let shares = try await keychain.getShares()
        guard let shareEntry = shares[curve.portalCurve.rawValue],
              !shareEntry.share.isEmpty
        else {
          logger.error("[PresignatureManager] No share found for curve \(curve.rawValue)")
          return nil
        }

        let metadata = MpcMetadata(
          clientPlatform: "NATIVE_IOS",
          clientPlatformVersion: SDK_VERSION,
          curve: curve.portalCurve,
          mpcServerVersion: "v6",
          optimized: true
        )
        let metadataString = try metadata.jsonString()

        let result = await binary.MobilePresign(
          apiKey, mpcHost, shareEntry.share, metadataString, curve.portalCurve
        )

        guard let data = result.data(using: .utf8) else {
          throw PresignatureManagerError.unableToParsePresignResponse
        }
        let parsed = try JSONDecoder().decode(PresignResponse.self, from: data)

        if let error = parsed.error, error.isValid() {
          throw PortalMpcError(error)
        }

        guard let id = parsed.id, let expiresAt = parsed.expiresAt, let presignData = parsed.data else {
          throw PresignatureManagerError.incompletePresignResponse
        }

        logger.debug("[PresignatureManager] Generated presignature \(id) for \(curve.rawValue)")
        return PresignatureEntry(id: id, expiresAt: expiresAt, data: presignData)
      } catch {
        logger.warn("[PresignatureManager] Presign failed for \(curve.rawValue) (attempt \(attempt + 1)/\(retryConfig.maxAttempts)): \(error.localizedDescription)")
        if attempt < retryConfig.maxAttempts - 1 {
          let rawDelay = UInt64(Double(retryConfig.baseDelayNs) * pow(retryConfig.multiplier, Double(attempt)))
          let delay = min(rawDelay, retryConfig.maxDelayNs)
          try? await Task.sleep(nanoseconds: delay)
        }
      }
    }
    logger.error("[PresignatureManager] Presign failed for \(curve.rawValue) after \(retryConfig.maxAttempts) attempts")
    return nil
  }

  private func fillBuffer(curve: PresignatureSupportedCurve) async {
    guard !Task.isCancelled else { return }

    guard let keychain else {
      logger.error("[PresignatureManager] Keychain deallocated, cannot fill buffer for \(curve.rawValue)")
      return
    }

    guard await guard_.tryAcquireFillLock(curve.rawValue) else {
      logger.debug("[PresignatureManager] Buffer fill already in progress for \(curve.rawValue), skipping")
      return
    }
    defer {
      Task { [guard_] in
        await guard_.releaseFillLock(curve.rawValue)
      }
    }

    do {
      let max = maxForCurve(curve)

      let removed = try await guard_.cleanup(keychain: keychain, curve: curve.rawValue)
      if removed > 0 {
        logger.debug("[PresignatureManager] Cleaned up \(removed) expired presignatures for \(curve.rawValue)")
      }

      let currentCount = try await guard_.getCount(keychain: keychain, curve: curve.rawValue)
      let needed = max - currentCount

      guard needed > 0 else {
        logger.debug("[PresignatureManager] Buffer full for \(curve.rawValue) (\(currentCount)/\(max))")
        return
      }

      logger.debug("[PresignatureManager] Filling buffer for \(curve.rawValue): need \(needed) presignatures")

      var generated = 0
      for _ in 0 ..< needed {
        guard !Task.isCancelled else {
          logger.debug("[PresignatureManager] Fill cancelled for \(curve.rawValue) after generating \(generated)/\(needed)")
          return
        }

        guard let entry = await preSign(curve: curve) else {
          logger.error("[PresignatureManager] Presign failed for \(curve.rawValue) after \(retryConfig.maxAttempts) attempts, stopping buffer fill")
          break
        }

        guard !Task.isCancelled else {
          logger.debug("[PresignatureManager] Fill cancelled before insert for \(curve.rawValue)")
          return
        }

        do {
          try await guard_.insert(keychain: keychain, curve: curve.rawValue, entry: entry)
          generated += 1
        } catch {
          logger.error("[PresignatureManager] Failed to store presignature for \(curve.rawValue): \(error.localizedDescription)")
        }
      }

      logger.debug("[PresignatureManager] Buffer fill complete for \(curve.rawValue): stored \(generated)/\(needed)")
    } catch {
      logger.warn("[PresignatureManager] Failed to initialize presignature buffers: \(error.localizedDescription)")
    }
  }

  private func cancelAllFillTasks() {
    for curve in PresignatureSupportedCurve.allCases {
      fillTasks[curve.rawValue]?.cancel()
      fillTasks.remove(curve.rawValue)
    }
  }
}

// MARK: - PresignatureGuard

private actor PresignatureGuard {
  private var activeFills: Set<String> = []

  func tryAcquireFillLock(_ curve: String) -> Bool {
    guard !activeFills.contains(curve) else { return false }
    activeFills.insert(curve)
    return true
  }

  func releaseFillLock(_ curve: String) {
    activeFills.remove(curve)
  }

  func pop(keychain: PortalKeychainProtocol, curve: String) async -> PresignatureEntry? {
    return try? await keychain.popOldestPresignature(curve)
  }

  func insert(keychain: PortalKeychainProtocol, curve: String, entry: PresignatureEntry) async throws {
    try await keychain.insertPresignature(curve, entry)
  }

  @discardableResult
  func cleanup(keychain: PortalKeychainProtocol, curve: String) async throws -> Int {
    return try await keychain.cleanupExpiredPresignatures(curve)
  }

  func getCount(keychain: PortalKeychainProtocol, curve: String) async throws -> Int {
    return try await keychain.getPresignatures(curve).count
  }
}

// MARK: - PresignatureManagerError

enum PresignatureManagerError: LocalizedError {
  case unableToParsePresignResponse
  case incompletePresignResponse

  var errorDescription: String? {
    switch self {
    case .unableToParsePresignResponse:
      return "Unable to parse presign response as UTF-8 data"
    case .incompletePresignResponse:
      return "Presign response missing required fields (id, expiresAt, or data)"
    }
  }
}

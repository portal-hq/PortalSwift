//
//  PortalTracing.swift
//  PortalSwift
//
//  Utilities for request tracing via the `X-Portal-Trace-Id` header.
//

import Foundation

/// The trace ID header used by connect-api (client + custodian APIs).
public let PORTAL_TRACE_ID_HEADER = "X-Portal-Trace-Id"

/// Generates a UUID v4 trace ID for request correlation.
/// The value is lowercased to stay consistent with the other Portal SDKs.
public func generateTraceId() -> String {
  UUID().uuidString.lowercased()
}

// MARK: - Portal-owned host detection

/// The apex domains Portal operates. A host is Portal-owned when it is one of these
/// exactly or ends with `.<apex>`; anything else (including hosts that merely contain
/// the string, such as `notportalhq.io` or `portalhq.io.attacker.com`) is a third party.
private let portalOwnedApexDomains = ["portalhq.io", "portalhq.dev"]

/// Loopback hosts used when pointing the SDK at a locally running connect-api. They are
/// treated as Portal-owned so local development receives the same credential and trace
/// behaviour as production, mirroring the Android SDK (`Tracing.kt`).
private let localDevelopmentHosts: Set<String> = ["localhost", "127.0.0.1"]

/// The only IPv6 literal accepted as Portal-owned: the loopback address, i.e. `http://[::1]`.
private let ipv6LoopbackLiteral = "::1"

// MARK: - Registered hosts

/// Hosts a `Portal`, `PortalApi`, `PortalConnect` or `PortalAuth` instance was configured with,
/// treated as Portal-owned by `isPortalOwnedUrl(_:)` in addition to the static allow-list.
///
/// Without this, an integrator who points `apiHost` / `mpcHost` / `enclaveMPCHost` /
/// `webSocketServer` at a domain outside `portalhq.io` — a custodian proxy, a private staging
/// domain — would have every 401 from their own backend classified as third-party, and session
/// invalidation would silently never fire; the RPC bearer and the trace header would be withheld
/// the same way. The Web SDK's `isPortalGatewayUrl` trusts the configured host for the same
/// reason. Only hosts the SDK was *constructed* with are registered; `rpcConfig` URLs never are,
/// because a custom RPC gateway is exactly what the bearer gate must keep untrusted. Process-wide
/// and lock-guarded, like `CredentialInvalidationRegistry`: a host is a deployment fact, not
/// per-instance state. Public so a host that fronts Portal through its own domain can register
/// it explicitly.
public enum PortalOwnedHosts {
  private static let lock = NSLock()
  private static var hosts: Set<String> = []

  /// Registers each value as a Portal-owned host. Accepts a bare host (`api.custodian.example`),
  /// a host with a port, or a full URL; the host component is extracted, lowercased and
  /// trailing-dot trimmed, and matched afterwards whole or as a dot-anchored suffix. Values
  /// that do not yield a well-formed host name (percent-encoding, IP literals, userinfo) are
  /// ignored rather than trusted.
  public static func register(_ values: String...) {
    let normalized = values.compactMap(Self.normalizedHost)
    guard !normalized.isEmpty else {
      return
    }
    self.lock.lock()
    defer { self.lock.unlock() }
    self.hosts.formUnion(normalized)
  }

  /// `true` when `host` — already lowercased and trailing-dot trimmed — is a registered host or
  /// a subdomain of one.
  static func contains(_ host: String) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.hosts.contains { registered in host == registered || hasDotAnchoredSuffix(host, registered) }
  }

  /// Test seam: forgets every registered host.
  static func resetForTesting() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.hosts.removeAll()
  }

  private static func normalizedHost(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    // A full URL: take its host. A bare host, optionally with a port: parse it as one.
    let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
    guard !rawHostContainsPercentEncoding(candidate),
          let components = URLComponents(string: candidate),
          // `user@evil.example` would otherwise register `evil.example`.
          components.user == nil, components.password == nil,
          let rawHost = components.percentEncodedHost, !rawHost.isEmpty
    else {
      return nil
    }
    let host = trimTrailingDots(rawHost.lowercased())
    guard !host.isEmpty, ipv6LiteralValue(in: host) == nil, isWellFormedHostName(host) else {
      return nil
    }
    return host
  }
}

/// Decides whether a URL points at infrastructure Portal operates.
///
/// This is the single gate that decides three security-relevant behaviours in the SDK:
/// whether the client's bearer credential may be attached to an RPC request, whether an
/// HTTP 401 from that URL should invalidate the credential through the unauthorized hook,
/// and whether the `X-Portal-Trace-Id` header is sent at all. A false positive leaks the
/// credential or trace to a third party; a false negative silently disables session
/// invalidation. The rules therefore favour rejecting anything that is not unambiguously a
/// Portal host, and every step is deliberate:
///
/// - The URL must parse with a non-empty scheme. A scheme-less `//api.portalhq.io/x` still
///   yields a host from `URLComponents`, but it is not a request the SDK would ever send, so it
///   is rejected rather than trusted.
/// - The host is read from `percentEncodedHost`, never `host`. `host` percent-decodes, so
///   `https://attacker.com%2f.portalhq.io/rpc` becomes `attacker.com/.portalhq.io` and passes a
///   naive suffix test; it also un-punycodes IDNs. The raw form keeps those bytes visible so
///   the character-set check below can reject them.
/// - The host is lowercased and trailing dots are trimmed (`api.portalhq.io.` is the
///   fully-qualified spelling of the same host).
/// - A bracketed IPv6 literal is accepted only when it is exactly the loopback `[::1]`. Any
///   other host must match `^[a-z0-9][a-z0-9._-]*$` with no empty labels, which rejects residual
///   percent-encoding, path/query/fragment/userinfo characters, unbracketed colons, and
///   leading dots or hyphens.
/// - Only then are the allow-lists consulted: `localhost`, `127.0.0.1` and `*.localhost` for
///   local development, `portalhq.io` / `portalhq.dev` as the whole host or as a dot-anchored
///   suffix, and finally the hosts the SDK was configured with (`PortalOwnedHosts`), matched the
///   same way.
///
/// The scan is a hand-rolled linear pass over the UTF-8 bytes (no regular expressions), so a
/// hostile multi-hundred-kilobyte input completes in linear time.
///
/// - Parameter url: The absolute URL string to classify.
/// - Returns: `true` only when the host is unambiguously Portal-owned or a local loopback.
public func isPortalOwnedUrl(_ url: String) -> Bool {
  // Refuse any percent-encoding in the raw host before parsing. Foundation's URL parser changed
  // between iOS 17 (CFURL) and iOS 18+ (swift-foundation): the older one hands back an already
  // decoded host for some encodings, so `attacker.com%2f.portalhq.io` can reach the suffix test
  // as `attacker.com/.portalhq.io`, or `a%2eportalhq%2eio` as `a.portalhq.io`. No Portal or
  // loopback host is ever spelled with a `%`, so the raw string is the parser-independent gate.
  guard !rawHostContainsPercentEncoding(url) else {
    return false
  }

  guard let components = URLComponents(string: url),
        let scheme = components.scheme, !scheme.isEmpty,
        let rawHost = components.percentEncodedHost, !rawHost.isEmpty
  else {
    return false
  }

  let host = trimTrailingDots(rawHost.lowercased())
  guard !host.isEmpty else {
    return false
  }

  // An IP literal is never matched against the domain allow-list; only loopback is accepted.
  if let ipv6Literal = ipv6LiteralValue(in: host) {
    return ipv6Literal == ipv6LoopbackLiteral
  }

  guard isWellFormedHostName(host) else {
    return false
  }

  if localDevelopmentHosts.contains(host) || hasDotAnchoredSuffix(host, "localhost") {
    return true
  }

  for apex in portalOwnedApexDomains where host == apex || hasDotAnchoredSuffix(host, apex) {
    return true
  }

  // Hosts an SDK instance was configured with (`apiHost`, `mpcHost`, `enclaveMPCHost`,
  // `webSocketServer`, `PortalAuth`'s `apiHost`) — see `PortalOwnedHosts`.
  return PortalOwnedHosts.contains(host)
}

/// `true` when the authority's host portion of the raw URL string contains a `%`.
///
/// Scans the text between `://` and the first `/`, `?` or `#`, after dropping any `user:pass@`
/// prefix (split on the *last* literal `@`, so an encoded `%40` never creates a fake boundary).
/// A bracketed IPv6 zone id (`[fe80::1%25en0]`) also contains `%` and is rejected; only `[::1]`
/// is accepted by the caller anyway.
private func rawHostContainsPercentEncoding(_ url: String) -> Bool {
  guard let schemeEnd = url.range(of: "://") else {
    return false
  }
  var authority = url[schemeEnd.upperBound...]
  if let end = authority.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
    authority = authority[..<end]
  }
  if let at = authority.lastIndex(of: "@") {
    authority = authority[authority.index(after: at)...]
  }
  return authority.contains("%")
}

/// Removes every trailing `.` from the host by walking backwards over the UTF-8 view, so a
/// host followed by hundreds of thousands of dots is handled in a single linear pass without
/// allocating intermediate strings.
private func trimTrailingDots(_ host: String) -> String {
  let utf8 = host.utf8
  var end = utf8.endIndex
  while end > utf8.startIndex {
    let previous = utf8.index(before: end)
    guard utf8[previous] == UInt8(ascii: ".") else {
      break
    }
    end = previous
  }
  return String(host[utf8.startIndex ..< end])
}

/// Extracts the IPv6 address when the host is an IP literal. Foundation returns the
/// bracketed form (`[::1]`) from `percentEncodedHost` on most OS versions, but newer parsers
/// may strip the brackets, so a bare host containing a colon is treated as a literal too:
/// a colon can never appear in a well-formed registered name. Returns `nil` for a regular
/// host name, or an empty string for a malformed literal so the caller rejects it.
private func ipv6LiteralValue(in host: String) -> String? {
  let utf8 = host.utf8
  if utf8.first == UInt8(ascii: "[") {
    guard utf8.count >= 2, utf8.last == UInt8(ascii: "]") else {
      return ""
    }
    let start = utf8.index(after: utf8.startIndex)
    let end = utf8.index(before: utf8.endIndex)
    return String(host[start ..< end])
  }
  if utf8.contains(UInt8(ascii: ":")) {
    return host
  }
  return nil
}

/// Checks the host against `^[a-z0-9][a-z0-9._-]*$` and rejects empty labels (`a..b`). The
/// input is already lowercased and stripped of trailing dots, so uppercase letters and a
/// trailing dot cannot reach this point. Any byte outside the set (including `%`, `/`, `#`,
/// `?`, `@`, `:` and non-ASCII) fails the check.
private func isWellFormedHostName(_ host: String) -> Bool {
  let utf8 = host.utf8
  guard let first = utf8.first, isAsciiLowercaseAlphanumeric(first) else {
    return false
  }

  var previousWasDot = false
  for byte in utf8.dropFirst() {
    if byte == UInt8(ascii: ".") {
      if previousWasDot {
        return false
      }
      previousWasDot = true
      continue
    }
    guard isAsciiLowercaseAlphanumeric(byte) || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "_") else {
      return false
    }
    previousWasDot = false
  }
  return true
}

private func isAsciiLowercaseAlphanumeric(_ byte: UInt8) -> Bool {
  (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")) || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
}

/// `true` when `host` ends with `.<suffix>`. The leading dot is what stops `notportalhq.io`
/// or `evil-portalhq.io` from matching `portalhq.io`.
private func hasDotAnchoredSuffix(_ host: String, _ suffix: String) -> Bool {
  host.hasSuffix(".\(suffix)")
}

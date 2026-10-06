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

/// Hosts an SDK object was configured with — `Portal`, `PortalApi` and each of its integration
/// APIs, `PortalProvider`, `PortalConnect`, `PortalAuth` — treated as Portal-owned by
/// `isPortalOwnedUrl(_:)` in addition to the static allow-list. Every object that installs a 401
/// hook on a transport registers the host that transport will be talking to, so a standalone
/// integration API on a custom `apiHost` reports a dead session the way one built by `PortalApi`
/// does, and sends the trace header there.
///
/// Without this, an integrator who points `apiHost` / `mpcHost` / `enclaveMPCHost` /
/// `webSocketServer` at a domain outside `portalhq.io` — a custodian proxy, a private staging
/// domain — would have every 401 from their own backend classified as third-party, and session
/// invalidation would silently never fire; the trace header would be withheld the same way. The
/// Web SDK's `isPortalGatewayUrl` trusts the configured host for the same reason. Only hosts the
/// SDK was *constructed* with are registered; `rpcConfig` URLs never are, because a custom RPC
/// gateway is exactly what the bearer gate must keep untrusted.
///
/// The RPC bearer — the one gate that *sends* a credential — does not consult this registry.
/// `PortalProvider` trusts the static allow-list plus the hosts and ports its own `Portal` was
/// constructed with (`isPortalRpcUrl(_:configuredEndpoints:)`), so constructing another `Portal`,
/// `PortalApi`, `PortalAuth` or `PortalConnect` in the process with a custom host can never route
/// this instance's credential to an `rpcConfig` URL on that host. Process-wide and lock-guarded, like
/// `CredentialInvalidationRegistry`, for the 401 and trace gates, where a false positive costs a
/// spurious invalidation or a trace id — never a credential. Public so a host that fronts Portal
/// through its own domain can register it explicitly — each hostname on its own, because matching
/// is exact (see `matches(_:anyOf:)`).
public enum PortalOwnedHosts {
  private static let lock = NSLock()
  private static var hosts: Set<String> = []

  /// Registers each value as a Portal-owned host. Accepts a bare host (`api.custodian.example`),
  /// a host with a port, or a full URL; the host component is extracted, lowercased and
  /// trailing-dot trimmed, and matched afterwards by exact equality — a subdomain of a registered
  /// host is not covered and has to be registered itself (see `matches(_:anyOf:)`). Values that
  /// do not yield a well-formed host name (percent-encoding, IP literals, userinfo) are ignored
  /// rather than trusted.
  public static func register(_ values: String...) {
    self.register(contentsOf: values)
  }

  /// `register(_:)` for a host list built at runtime (`PortalProvider`'s `configuredHosts`).
  static func register(contentsOf values: [String]) {
    let normalized = values.compactMap(Self.normalizedHost)
    guard !normalized.isEmpty else {
      return
    }
    self.lock.lock()
    defer { self.lock.unlock() }
    self.hosts.formUnion(normalized)
  }

  /// `true` when `host` — already lowercased and trailing-dot trimmed — is a registered host.
  static func contains(_ host: String) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return Self.matches(host, anyOf: self.hosts)
  }

  /// The normalized host and port of every value that yields a well-formed host — the same host
  /// normalization `register` applies, plus the port the value named — for the instance-scoped RPC
  /// bearer gate (`isPortalRpcUrl(_:configuredEndpoints:)`), which has to compare ports where the
  /// registry only compares hosts.
  static func normalizeEndpoints(_ values: [String]) -> Set<PortalConfiguredEndpoint> {
    Set(values.compactMap(normalizedEndpoint))
  }

  /// `true` when `host` — already lowercased and trailing-dot trimmed — equals one of `hosts`.
  ///
  /// Exact, with no suffix rule, unlike the static Portal apexes: a configured host names one
  /// endpoint the integrator pointed the SDK at, not a domain they are known to own. Matching
  /// subdomains would let an apex passed as `apiHost` (`custodian.example`) trust every host
  /// beneath it — including third-party CNAMEs — and, through the RPC bearer gate, send the
  /// credential to an `rpcConfig` URL there. The Web SDK's `isPortalGatewayUrl` draws the same
  /// line; a second host has to be configured or registered on its own. The instance-scoped RPC
  /// bearer gate compares `PortalConfiguredEndpoint.host` by the same equality (and the port on
  /// top), so the two can never disagree on what a configured host covers.
  static func matches(_ host: String, anyOf hosts: Set<String>) -> Bool {
    hosts.contains(host)
  }

  /// Test seam: forgets every registered host.
  static func resetForTesting() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.hosts.removeAll()
  }

  private static func normalizedHost(_ value: String) -> String? {
    normalizedEndpoint(value)?.host
  }

  private static func normalizedEndpoint(_ value: String) -> PortalConfiguredEndpoint? {
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
    return PortalConfiguredEndpoint(host: host, port: components.port)
  }
}

/// One host an SDK instance was configured with, as the RPC bearer gate compares it: the host
/// normalized the way `PortalOwnedHosts.register(_:)` normalizes it, and the port the
/// configuration named — `nil` when it named none, which means the scheme's default at match
/// time. Kept apart from the registry's host set because the bearer gate has to compare ports: a
/// loopback `apiHost` differs from a local Anvil or Hardhat node by its port and nothing else.
struct PortalConfiguredEndpoint: Hashable {
  let host: String
  let port: Int?
}

/// Decides whether a URL points at infrastructure Portal operates.
///
/// This is the gate for two security-relevant behaviours in the SDK: whether an HTTP 401 from
/// that URL should invalidate the credential through the unauthorized hook, and whether the
/// `X-Portal-Trace-Id` header is sent at all. The third — whether the client's bearer credential
/// may be attached to an RPC request — is `isPortalRpcUrl(_:configuredEndpoints:)`, which runs
/// the same parse and then asks for more. A false positive leaks the credential or trace to a
/// third party; a false negative silently disables session invalidation. The rules therefore
/// favour rejecting anything that is not unambiguously a Portal host, and every step is
/// deliberate:
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
///   suffix, and finally the hosts the SDK was configured with (`PortalOwnedHosts`), matched
///   exactly — the suffix rule is reserved for the apexes Portal itself operates.
///   `isPortalRpcUrl(_:configuredEndpoints:)` is the stricter variant the RPC bearer gate uses:
///   the configured-host step is limited to one instance's own hosts and ports, a loopback host
///   is trusted only as one of those, and a public host must be reached over `https`.
///
/// The scan is a hand-rolled linear pass over the UTF-8 bytes (no regular expressions), so a
/// hostile multi-hundred-kilobyte input completes in linear time.
///
/// - Parameter url: The absolute URL string to classify.
/// - Returns: `true` only when the host is unambiguously Portal-owned or a local loopback.
public func isPortalOwnedUrl(_ url: String) -> Bool {
  guard let parsed = parsePortalHost(url) else {
    return false
  }
  switch parsed.kind {
  case .loopback, .portalApex:
    return true
  case .candidate:
    // Hosts an SDK instance was configured with (`apiHost`, `mpcHost`, `enclaveMPCHost`,
    // `webSocketServer`, `PortalAuth`'s `apiHost`) — see `PortalOwnedHosts`.
    return PortalOwnedHosts.contains(parsed.host)
  }
}

/// The gate for the RPC bearer — the one place the SDK *sends* a credential — with the
/// configured-host step limited to `configuredEndpoints`, the normalized hosts and ports *one*
/// SDK instance was constructed with (`PortalOwnedHosts.normalizeEndpoints`), instead of the
/// process-wide registry.
///
/// Stricter than `isPortalOwnedUrl(_:)` in three ways, each mirroring the Android SDK's
/// `Provider.isPortalRpcUrl`, because a wrong answer here puts an end user's session token on the
/// wire rather than a trace id:
///
/// - A loopback host is **not** trusted on its own. `isPortalOwnedUrl(_:)` treats `localhost`,
///   `127.0.0.1`, `*.localhost` and `[::1]` as Portal-owned, which is right for a trace id, but
///   the canonical custom gateway during development is a local Anvil or Hardhat node
///   (`http://localhost:8545`), which shares its host with a local Portal API and differs only by
///   port. A loopback URL receives the bearer only when its host and port are a configured
///   endpoint of this instance — the `apiHost` it was built with, which is also what `Portal`
///   derives every default RPC URL from, so the equality means "this is our own RPC endpoint".
///   Cleartext is allowed there and there alone, because the request never leaves the machine.
///   The IPv6 loopback literal cannot be configured (`PortalOwnedHosts` rejects IP literals other
///   than dotted decimals), so `[::1]` never receives the bearer.
/// - A static Portal apex must be reached over `https`. `http://api.portalhq.io/rpc` is a genuine
///   Portal host reached in cleartext, and the credential would travel unencrypted.
/// - A configured host must match on host **and** port, over `https`. An absent port on either
///   side means the scheme's default, so `api.custodian.example` matches
///   `https://api.custodian.example/rpc` but not `https://api.custodian.example:8443/rpc`; a
///   second endpoint has to be configured on its own. Comparing resolved ports is sound only
///   because the scheme is pinned first — without that, a port-less configured host would compare
///   each URL's own default against itself, which no URL could fail.
///
/// Trusting the registry here would let any other `Portal`, `PortalApi`, `PortalAuth` or
/// `PortalConnect` in the process, merely by being constructed with a custom host, route this
/// instance's credential to an `rpcConfig` URL on that host. Every structural rejection is
/// identical to `isPortalOwnedUrl(_:)`; a scheme other than `http` / `https` is refused, since an
/// RPC request cannot be made over it.
func isPortalRpcUrl(_ url: String, configuredEndpoints: Set<PortalConfiguredEndpoint>) -> Bool {
  guard let parsed = parsePortalHost(url),
        let schemeDefaultPort = defaultPort(forScheme: parsed.scheme)
  else {
    return false
  }
  let isTls = parsed.scheme == "https"
  let matchesConfiguredEndpoint = configuredEndpoints.contains { endpoint in
    endpoint.host == parsed.host && (endpoint.port ?? schemeDefaultPort) == (parsed.port ?? schemeDefaultPort)
  }

  switch parsed.kind {
  case .portalApex:
    return isTls
  case .loopback:
    return matchesConfiguredEndpoint
  case .candidate:
    return isTls && matchesConfiguredEndpoint
  }
}

/// The well-known port of the schemes an RPC request can use; `nil` for any other scheme.
private func defaultPort(forScheme scheme: String) -> Int? {
  switch scheme {
  case "http":
    return 80
  case "https":
    return 443
  default:
    return nil
  }
}

/// What the structural checks and static allow-lists decide about a URL before any
/// configured-host step: which allow-list the host fell into (or none), plus the scheme and port
/// the RPC bearer gate needs on top.
private struct ParsedPortalHost {
  enum Kind {
    /// `localhost`, `127.0.0.1`, `*.localhost` or `[::1]`: the developer's own machine.
    case loopback
    /// `portalhq.io` / `portalhq.dev`, whole or as a dot-anchored suffix: an apex Portal operates.
    case portalApex
    /// A well-formed host outside the static lists; configured-host trust decides.
    case candidate
  }

  let kind: Kind
  /// Lowercased and trailing-dot trimmed; still bracketed for the IPv6 loopback literal.
  let host: String
  /// Lowercased.
  let scheme: String
  /// The explicit port, `nil` when the URL named none.
  let port: Int?
}

/// The shared front half of `isPortalOwnedUrl(_:)` and `isPortalRpcUrl(_:configuredEndpoints:)`
/// — see `isPortalOwnedUrl(_:)` for the rules each step enforces. `nil` for a URL that is
/// malformed, hostile, or an IP literal other than loopback: never owned, whatever is configured.
private func parsePortalHost(_ url: String) -> ParsedPortalHost? {
  // Refuse any percent-encoding in the raw host before parsing. Foundation's URL parser changed
  // between iOS 17 (CFURL) and iOS 18+ (swift-foundation): the older one hands back an already
  // decoded host for some encodings, so `attacker.com%2f.portalhq.io` can reach the suffix test
  // as `attacker.com/.portalhq.io`, or `a%2eportalhq%2eio` as `a.portalhq.io`. No Portal or
  // loopback host is ever spelled with a `%`, so the raw string is the parser-independent gate.
  guard !rawHostContainsPercentEncoding(url) else {
    return nil
  }

  guard let components = URLComponents(string: url),
        let scheme = components.scheme, !scheme.isEmpty,
        let rawHost = components.percentEncodedHost, !rawHost.isEmpty
  else {
    return nil
  }

  let host = trimTrailingDots(rawHost.lowercased())
  guard !host.isEmpty else {
    return nil
  }
  let lowercasedScheme = scheme.lowercased()

  // An IP literal is never matched against the domain allow-list; only loopback is accepted.
  if let ipv6Literal = ipv6LiteralValue(in: host) {
    guard ipv6Literal == ipv6LoopbackLiteral else {
      return nil
    }
    return ParsedPortalHost(kind: .loopback, host: host, scheme: lowercasedScheme, port: components.port)
  }

  guard isWellFormedHostName(host) else {
    return nil
  }

  if localDevelopmentHosts.contains(host) || hasDotAnchoredSuffix(host, "localhost") {
    return ParsedPortalHost(kind: .loopback, host: host, scheme: lowercasedScheme, port: components.port)
  }

  for apex in portalOwnedApexDomains where host == apex || hasDotAnchoredSuffix(host, apex) {
    return ParsedPortalHost(kind: .portalApex, host: host, scheme: lowercasedScheme, port: components.port)
  }

  return ParsedPortalHost(kind: .candidate, host: host, scheme: lowercasedScheme, port: components.port)
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

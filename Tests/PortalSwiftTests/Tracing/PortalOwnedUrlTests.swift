//
//  PortalOwnedUrlTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Pins the behaviour of `isPortalOwnedUrl(_:)`, the single gate that decides whether the
/// client's bearer credential is attached to an RPC request, whether a 401 from that URL
/// invalidates the credential, and whether the `X-Portal-Trace-Id` header is sent at all.
///
/// A false positive here hands a Client API Key or a session token to an attacker-controlled
/// host, so the bulk of this suite is the attacker-hostname list the Android SDK regressed on
/// (`TracingTest.kt`) plus the iOS-specific parsing hazards called out in PLAN.md 4.2:
/// percent-encoded hosts that `URLComponents.host` silently decodes, scheme-less URLs that still
/// yield a host, IDN look-alikes, bracketed IPv6 literals, and multi-hundred-kilobyte hostile
/// inputs that must finish in linear time. The function is pure, so no fixtures are needed; the
/// registry reset and logger sink follow the suite-wide convention so a future change that makes
/// the gate log or touch shared state is caught by the same tests.
final class PortalOwnedUrlTests: XCTestCase {
  private var logger = RecordingLogger()

  override func setUp() {
    super.setUp()
    CredentialInvalidationRegistry.shared.resetForTesting()
    // The false vectors below assume no test constructed an SDK object against one of them.
    PortalOwnedHosts.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDown() {
    self.logger.uninstall()
    PortalOwnedHosts.resetForTesting()
    CredentialInvalidationRegistry.shared.resetForTesting()
    super.tearDown()
  }

  // MARK: - Vector sets

  /// The Android `TracingTest` "recognizes Portal and local hosts" true list, minus
  /// `http://10.0.2.2:3001/...`: that address is the Android emulator's alias for the host
  /// machine and has no meaning on iOS, so the iOS gate deliberately does not know it.
  private static let androidTrueVectors: [String] = [
    "https://api.portalhq.io/api/v3/clients/me",
    "https://mpc-client.portalhq.io/v1/sign",
    "https://portalhq.io/api/v3/clients/me",
    "https://api.portalhq.dev/api/v3/clients/me",
    "https://portalhq.dev/api/v3/clients/me",
    "http://localhost:3001/api/v3/clients/me",
    // `matches the hostname case-insensitively and through a trailing dot`
    "https://API.PortalHQ.IO/api/v3/clients/me",
    "https://api.portalhq.io./api/v3/clients/me",
    "https://portalhq.io./api/v3/clients/me"
  ]

  /// Every false vector from the three Android `isPortalOwnedUrl` tests. The
  /// `10.0.2.2.attacker.com` entry is kept because its verdict (false) is the same on both
  /// platforms; only the *true* emulator vector is platform-specific.
  private static let androidFalseVectors: [String] = [
    // `recognizes Portal and local hosts`
    "https://www.googleapis.com/drive/v3/files",
    "https://min-api.cryptocompare.com/data/price",
    // `rejects hosts that merely look like Portal (regression)`
    "https://api.portalhq.attacker.com/rpc",
    "https://api.portalhq.io.attacker.com/rpc",
    "https://portalhq.io.attacker.com/rpc",
    "https://evil-portalhq.com/rpc",
    "https://notportalhq.io/rpc",
    "https://portalhq.io.evil.dev/rpc",
    "https://10.0.2.2.attacker.com/rpc",
    "https://localhost.attacker.com/rpc",
    "https://attacker.com/api.portalhq.io/rpc",
    "https://api.portalhq.io@attacker.com/rpc",
    // `rejects what it cannot parse a host out of`
    "not-a-url",
    "",
    "api.portalhq.io/api/v3/clients/me"
  ]

  /// A mixed bag of true and false vectors with their known verdicts, used by the concurrency
  /// test so every worker checks against the *documented* answer rather than against whatever
  /// the function happened to return on the main thread.
  private static let mixedVectors: [(url: String, expected: Bool)] =
    androidTrueVectors.map { ($0, true) }
      + androidFalseVectors.map { ($0, false) }
      + [
        ("https://user:pass@api.portalhq.io/", true),
        ("http://[::1]:3001/x", true),
        ("http://app.localhost/x", true),
        ("wss://connect.portalhq.io", true),
        ("https://attacker.com%2f.portalhq.io/rpc", false),
        ("//api.portalhq.io/api", false),
        ("https://xn--portalhq-x0a.io/", false),
        ("http://[fe80::1]/", false)
      ]

  // MARK: - Helpers

  /// Asserts every URL in `urls` classifies as `expected`, reporting each offending vector on
  /// its own line so a regression names the exact hostname that slipped through instead of a
  /// bare "false is not true".
  private func assertOwned(
    _ urls: [String],
    _ expected: Bool,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for url in urls {
      let actual = isPortalOwnedUrl(url)
      XCTAssertEqual(
        actual,
        expected,
        "isPortalOwnedUrl(\(url.debugDescription)) returned \(actual), expected \(expected)",
        file: file,
        line: line
      )
    }
  }

  /// Runs the gate once and returns both its verdict and the wall-clock time it took. Named to
  /// avoid shadowing `XCTestCase.measure`, which would run the block ten times and report a
  /// baseline instead of enforcing a hard ceiling.
  private func timedVerdict(for url: String) -> (verdict: Bool, seconds: TimeInterval) {
    let start = Date()
    let verdict = isPortalOwnedUrl(url)
    return (verdict, Date().timeIntervalSince(start))
  }

  /// Builds an absolute URL of exactly `totalLength` UTF-8 bytes whose host is one very long
  /// label followed by `.portalhq.io`, so the string is a "Portal host" by suffix but far
  /// beyond anything a real request would carry.
  private func longPortalHostUrl(totalLength: Int) -> String {
    let prefix = "https://"
    let suffix = ".portalhq.io/x"
    let labelLength = max(1, totalLength - prefix.count - suffix.count)
    return prefix + String(repeating: "a", count: labelLength) + suffix
  }

  // MARK: - isPortalOwnedUrl

  func test_isPortalOwnedUrl_willReturnTrue_forPortalAndLocalHosts() {
    self.assertOwned([
      "https://api.portalhq.io/api/v3/clients/me",
      "https://mpc-client.portalhq.io/v1/sign",
      "https://portalhq.io/x",
      "https://api.portalhq.dev/x",
      "https://portalhq.dev/x",
      "https://web.portalhq.io/",
      "wss://connect.portalhq.io",
      "http://localhost:3001/x",
      "http://127.0.0.1:3001/x",
      "http://[::1]:3001/x",
      "http://app.localhost/x"
    ], true)
  }

  func test_isPortalOwnedUrl_willReturnFalse_forThirdPartyHosts() {
    self.assertOwned([
      "https://www.googleapis.com/drive/v3/files",
      "https://min-api.cryptocompare.com/data/price",
      "https://eth.llamarpc.com"
    ], false)
  }

  func test_isPortalOwnedUrl_willMatchCaseInsensitively() {
    self.assertOwned([
      "https://API.PortalHQ.IO/x",
      "https://API.PORTALHQ.IO/",
      "HTTPS://api.portalhq.io/"
    ], true)
  }

  func test_isPortalOwnedUrl_willMatchThroughTrailingDot() {
    // `api.portalhq.io.` is the fully-qualified spelling of the same host; a run of several
    // dots is not valid DNS but must still be trimmed rather than defeating the suffix match.
    self.assertOwned([
      "https://api.portalhq.io./x",
      "https://portalhq.io./x",
      "https://api.portalhq.io.../x"
    ], true)
  }

  func test_isPortalOwnedUrl_willIgnorePort() {
    self.assertOwned([
      "https://api.portalhq.io:443/x",
      "https://api.portalhq.io:8443/x",
      "http://localhost:65535/"
    ], true)
  }

  func test_isPortalOwnedUrl_willIgnoreUserinfo_whenHostIsPortal() {
    let password = "s3cr3t-p4ss"
    self.assertOwned(["https://user:\(password)@api.portalhq.io/"], true)

    // The gate is consulted for every request; it must never log the URL it inspects, because
    // a URL may carry userinfo (as here) or a token in its query.
    XCTAssertTrue(self.logger.entries.isEmpty, "isPortalOwnedUrl must not log; got \(self.logger.messages)")
    self.logger.assertNoSecret(password)
  }

  func test_isPortalOwnedUrl_willRejectUserinfoSpoof() {
    // Everything before `@` is userinfo; the real host is `attacker.com`.
    self.assertOwned([
      "https://api.portalhq.io@attacker.com/rpc",
      "https://api.portalhq.io:x@attacker.com/"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectLookalikeHosts() {
    // Every one of these is registrable by an attacker and passed the pre-Android-#456
    // substring/prefix check.
    self.assertOwned([
      "https://api.portalhq.attacker.com/rpc",
      "https://api.portalhq.io.attacker.com/rpc",
      "https://portalhq.io.attacker.com/rpc",
      "https://evil-portalhq.com/rpc",
      "https://notportalhq.io/rpc",
      "https://portalhq.io.evil.dev/rpc",
      "https://portalhq.io.evil.com/",
      "https://xportalhq.io/",
      "https://portalhq.iox/",
      "https://portalhq.dev.evil.com/"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectLocalhostLookalikes() {
    self.assertOwned([
      "https://localhost.attacker.com/rpc",
      "https://127.0.0.1.attacker.com/",
      "https://127.0.0.10/",
      "https://localhostx/",
      "https://notlocalhost/"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectHostInPath() {
    // The host is what is matched, never the path, query or fragment.
    self.assertOwned([
      "https://attacker.com/api.portalhq.io/rpc",
      "https://attacker.com/?u=https://api.portalhq.io",
      "https://attacker.com/#api.portalhq.io"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectPercentEncodedHost() {
    // `URLComponents.host` percent-decodes these into `attacker.com/.portalhq.io`,
    // `a.portalhq.io`, `api.portalhq.io` and so on, which would pass a suffix test. On iOS 17's
    // CFURL parser even `percentEncodedHost` can come back decoded, so the gate rejects a `%` in
    // the raw host text before parsing; that holds on every Foundation.
    self.assertOwned([
      "https://attacker.com%2f.portalhq.io/rpc",
      "https://attacker.com%2F.portalhq.io/rpc",
      "https://a%2eportalhq%2eio/",
      "https://a%2Eportalhq%2Eio/",
      "https://api%2eportalhq.io/",
      "https://api.portalhq.io%2e/",
      "https://attacker.com%23.portalhq.io/",
      "https://attacker.com%3f.portalhq.io/",
      "https://attacker.com%40api.portalhq.io/",
      "http://[fe80::1%25en0]/"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectSchemeless() {
    // `//api.portalhq.io/api` parses with a host but no scheme; the SDK never sends such a
    // request, so it must not be trusted. The bare forms parse with no host at all
    // (`localhost:3001` parses as scheme "localhost").
    self.assertOwned([
      "//api.portalhq.io/api",
      "api.portalhq.io/api/v3/clients/me",
      "api.portalhq.io",
      "localhost:3001"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectEmptyAndBlank() {
    self.assertOwned(["", "   ", "\n"], false)
  }

  func test_isPortalOwnedUrl_willRejectGarbage() {
    // None of these may crash; several make `URLComponents(string:)` return nil, the rest
    // parse with an empty host.
    self.assertOwned([
      "not-a-url",
      "::::",
      "https://",
      "https:///path",
      "https://?x=1",
      "https://#frag",
      "https:// api.portalhq.io",
      "https://api.portalhq.io\u{0}"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectIdnAndPunycodeLookalikes() {
    // `xn--portalhq-x0a.io` is the punycode of `portalçhq.io`; `URLComponents.host` would
    // un-punycode it. The Cyrillic `о` (U+043E) is visually identical to Latin `o`. The
    // fullwidth full stop (U+FF0E) is normalised to `.` by the parser, which turns the last
    // vector into `api.portalhq.io.attacker.com`, a plain look-alike.
    self.assertOwned([
      "https://xn--portalhq-x0a.io/",
      "https://p\u{043E}rtalhq.io/",
      "https://api.portalhq.io\u{FF0E}attacker.com/"
    ], false)
  }

  func test_isPortalOwnedUrl_willHandleIPv6Literals() {
    // Only the loopback literal is accepted; any other IP literal is never matched against the
    // domain allow-list, and a malformed bracket sequence fails to parse.
    self.assertOwned([
      "http://[::1]/x",
      "http://[::1]:3001/"
    ], true)
    self.assertOwned([
      "http://[fe80::1]/",
      "http://[::1].attacker.com/",
      "http://[/"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectHostWithIllegalCharacters() {
    // The host must match `^[a-z0-9][a-z0-9._-]*$` with no empty labels. Path, query, fragment
    // and userinfo delimiters can only reach the host percent-encoded (where the residual `%`
    // is itself illegal); an unbracketed colon makes the port unparsable.
    self.assertOwned([
      "https://api.portalhq.io%2fattacker.com/", // '/'
      "https://api.portalhq.io%23.attacker.com/", // '#'
      "https://api.portalhq.io%3f.attacker.com/", // '?'
      "https://api.portalhq.io%40attacker.com/", // '@'
      "https://api.portalhq.io:x/", // ':' unbracketed
      "https://api:portalhq.io/", // ':' unbracketed, mid-host
      "https://_api.portalhq.io/", // leading '_'
      "https://-api.portalhq.io/", // leading '-'
      "https://api..portalhq.io/", // empty label
      "https://.portalhq.io/" // leading dot
    ], false)
  }

  // MARK: - Registered hosts

  func test_isPortalOwnedUrl_willAcceptARegisteredHost_wholeOrAsDotAnchoredSuffix() {
    PortalOwnedHosts.register("api.custodian.example")

    self.assertOwned([
      "https://api.custodian.example/api/v3/clients/me",
      "https://API.Custodian.Example/api/v3/clients/me",
      "https://api.custodian.example./api/v3/clients/me",
      "https://rpc.api.custodian.example/rpc"
    ], true)
  }

  func test_isPortalOwnedUrl_willRejectLookalikesOfARegisteredHost() {
    PortalOwnedHosts.register("api.custodian.example")

    self.assertOwned([
      "https://api.custodian.example.attacker.com/rpc",
      "https://notapi.custodian.example/rpc",
      "https://custodian.example/rpc",
      "https://attacker.com/api.custodian.example",
      "https://api.custodian.example@attacker.com/rpc"
    ], false)
  }

  func test_isPortalOwnedUrl_willRejectACustomHost_untilItIsRegistered() {
    self.assertOwned(["https://api.custodian.example/api/v3/clients/me"], false)

    PortalOwnedHosts.register("api.custodian.example")

    self.assertOwned(["https://api.custodian.example/api/v3/clients/me"], true)
  }

  func test_isPortalOwnedUrl_configuredHosts_willIgnoreTheRegistry_andTrustOnlyTheGivenHosts() {
    PortalOwnedHosts.register("api.custodian.example")
    let mine = PortalOwnedHosts.normalize(["API.Mine.Example.", "https://mpc.mine.example:8443/path", "not a host%"])
    XCTAssertEqual(mine, ["api.mine.example", "mpc.mine.example"])

    // The registry's host is not this instance's.
    XCTAssertTrue(isPortalOwnedUrl("https://rpc.api.custodian.example/rpc"))
    XCTAssertFalse(isPortalOwnedUrl("https://rpc.api.custodian.example/rpc", configuredHosts: mine))
    XCTAssertFalse(isPortalOwnedUrl("https://rpc.api.custodian.example/rpc", configuredHosts: []))

    // This instance's hosts match whole or as a dot-anchored suffix, after the same normalization
    // `register` applies.
    XCTAssertTrue(isPortalOwnedUrl("https://api.mine.example/rpc", configuredHosts: mine))
    XCTAssertTrue(isPortalOwnedUrl("https://API.Mine.Example./rpc", configuredHosts: mine))
    XCTAssertTrue(isPortalOwnedUrl("https://rpc.mpc.mine.example/rpc", configuredHosts: mine))
    XCTAssertFalse(isPortalOwnedUrl("https://api.mine.example.attacker.com/rpc", configuredHosts: mine))
    XCTAssertFalse(isPortalOwnedUrl("https://notapi.mine.example/rpc", configuredHosts: mine))

    // The loopback and static allow-lists and the structural rejections are unchanged.
    XCTAssertTrue(isPortalOwnedUrl("https://api.portalhq.io/rpc", configuredHosts: []))
    XCTAssertTrue(isPortalOwnedUrl("http://localhost:8545", configuredHosts: []))
    XCTAssertFalse(isPortalOwnedUrl("https://attacker.com%2f.portalhq.io/rpc", configuredHosts: mine))
    XCTAssertFalse(isPortalOwnedUrl("https://api.mine.example@attacker.com/rpc", configuredHosts: mine))
  }

  func test_register_willAcceptFullUrlsAndPorts_andIgnoreValuesThatAreNotAHost() {
    PortalOwnedHosts.register(
      "https://proxy.custodian.example:8443/some/path?x=1",
      "mpc.custodian.example:9000",
      "   ",
      "attacker.com%2f.portalhq.io",
      "[2001:db8::1]",
      "user@evil.example"
    )

    self.assertOwned([
      "https://proxy.custodian.example/x",
      "wss://mpc.custodian.example/v1/sign"
    ], true)
    self.assertOwned([
      "https://evil.example/x",
      "https://attacker.com/x",
      "http://[2001:db8::1]/x"
    ], false)
  }

  func test_isPortalOwnedUrl_willAcceptSubdomainsWithHyphenAndDigits() {
    self.assertOwned([
      "https://mpc-client.portalhq.io/",
      "https://a1-b2.portalhq.dev/"
    ], true)
  }

  func test_isPortalOwnedUrl_willRequireDotAnchoredSuffix() {
    // The apex must be the whole host or preceded by a dot; a hyphen or nothing at all in
    // front of `portalhq` is a different, registrable domain.
    self.assertOwned([
      "https://myportalhq.io/",
      "https://api-portalhq.io/",
      "https://apiportalhq.dev/"
    ], false)
  }

  func test_isPortalOwnedUrl_willAcceptAnyScheme_whenHostIsPortal() {
    // Host-only rule: the scheme is merely required to be non-empty, so the WebSocket and
    // plain-HTTP spellings used against local connect-api builds are treated the same.
    self.assertOwned([
      "wss://api.portalhq.io",
      "ws://api.portalhq.io",
      "http://api.portalhq.io",
      "ftp://api.portalhq.io"
    ], true)
  }

  func test_isPortalOwnedUrl_willCompleteQuickly_forHostileLongInputs() {
    // Generous on purpose: this guards against a super-linear scan (seconds), not a slow CI
    // host. 0.1 s had a ~3x margin on fast hardware and would flake on a loaded runner.
    let limit: TimeInterval = 1.0

    // 8192-byte URL whose host is a single ~8 KB label under `.portalhq.io`. Foundation refuses
    // to yield a host longer than 2048 bytes, so this is rejected at the parse step; a host
    // that long is not a real Portal host in any case.
    let longHost = self.timedVerdict(for: self.longPortalHostUrl(totalLength: 8192))
    XCTAssertFalse(longHost.verdict)
    XCTAssertLessThan(longHost.seconds, limit, "8192-byte URL took \(longHost.seconds) s")

    // 200k slashes: no scheme, no host.
    let slashes = self.timedVerdict(for: String(repeating: "/", count: 200_000))
    XCTAssertFalse(slashes.verdict)
    XCTAssertLessThan(slashes.seconds, limit, "200k '/' took \(slashes.seconds) s")

    // 200k trailing dots after a real Portal host. The trailing-dot trim is a linear index scan,
    // so this must finish quickly; the verdict depends on whether the platform parser hands the
    // oversized host to the gate at all (Foundation caps the host at 2048 bytes and returns nil
    // above that). Pin the contract precisely: true exactly when a host was parsed, never a
    // crash or a slow path either way.
    let dotsUrl = "https://api.portalhq.io" + String(repeating: ".", count: 200_000) + "/x"
    let dots = self.timedVerdict(for: dotsUrl)
    let dotsHostParsed = URLComponents(string: dotsUrl)?.percentEncodedHost != nil
    XCTAssertEqual(dots.verdict, dotsHostParsed, "200k trailing dots must be trimmed whenever the parser yields the host")
    XCTAssertLessThan(dots.seconds, limit, "200k '.' took \(dots.seconds) s")

    // The longest trailing-dot run that is guaranteed to reach the gate on every supported
    // Foundation (host well under the 2048-byte cap) must still be trimmed down to the apex.
    let inCapDots = self.timedVerdict(for: "https://api.portalhq.io" + String(repeating: ".", count: 1024) + "/x")
    XCTAssertTrue(inCapDots.verdict, "1024 trailing dots must be trimmed by the index scan")
    XCTAssertLessThan(inCapDots.seconds, limit, "1024 '.' took \(inCapDots.seconds) s")

    // 200k-byte single label: not a Portal host, must not be quadratic in the charset scan.
    let label = self.timedVerdict(for: "https://" + String(repeating: "a", count: 200_000) + "/")
    XCTAssertFalse(label.verdict)
    XCTAssertLessThan(label.seconds, limit, "200k 'a' took \(label.seconds) s")

    // 200k `%2f` repeats, both bare and wrapped around a Portal suffix: the residual `%` bytes
    // must be rejected without decoding.
    let encoded = self.timedVerdict(for: "https://" + String(repeating: "%2f", count: 200_000) + "/")
    XCTAssertFalse(encoded.verdict)
    XCTAssertLessThan(encoded.seconds, limit, "200k '%2f' took \(encoded.seconds) s")

    let encodedSpoof = self.timedVerdict(
      for: "https://attacker.com" + String(repeating: "%2f", count: 200_000) + ".portalhq.io/"
    )
    XCTAssertFalse(encodedSpoof.verdict)
    XCTAssertLessThan(encodedSpoof.seconds, limit, "200k '%2f' spoof took \(encodedSpoof.seconds) s")
  }

  func test_isPortalOwnedUrl_willBeSafeUnderConcurrentCalls() throws {
    let vectors = Self.mixedVectors
    let lock = NSLock()
    var mismatches: [String] = []

    // Eight real threads released through one barrier, each walking 1000 vectors starting at a
    // different offset so the same URL is classified on several threads at once.
    try runConcurrently(8) { worker in
      for iteration in 0 ..< 1000 {
        let vector = vectors[(iteration + worker) % vectors.count]
        let verdict = isPortalOwnedUrl(vector.url)
        if verdict != vector.expected {
          lock.lock()
          mismatches.append("worker \(worker): \(vector.url.debugDescription) -> \(verdict), expected \(vector.expected)")
          lock.unlock()
        }
      }
    }

    lock.lock()
    let recorded = mismatches
    lock.unlock()
    XCTAssertTrue(recorded.isEmpty, "Non-deterministic verdicts under concurrency:\n\(recorded.joined(separator: "\n"))")
  }

  func test_isPortalOwnedUrl_willMatchAndroidVectorSet() {
    self.assertOwned(Self.androidTrueVectors, true)
    self.assertOwned(Self.androidFalseVectors, false)
  }

  // MARK: - PORTAL_TRACE_ID_HEADER

  func test_PORTAL_TRACE_ID_HEADER_willMatchConnectApiName() {
    XCTAssertEqual(PORTAL_TRACE_ID_HEADER, "X-Portal-Trace-Id")
  }

  // MARK: - generateTraceId

  func test_generateTraceId_willReturnLowercaseUuid_uniquePerCall() {
    let first = generateTraceId()
    let second = generateTraceId()

    XCTAssertNotNil(UUID(uuidString: first), "Trace ID should be a valid UUID")
    XCTAssertNotNil(UUID(uuidString: second), "Trace ID should be a valid UUID")
    XCTAssertEqual(first, first.lowercased(), "Trace ID should be lowercased")
    XCTAssertEqual(second, second.lowercased(), "Trace ID should be lowercased")
    XCTAssertNotEqual(first, second, "Trace IDs must be unique per call")
  }
}

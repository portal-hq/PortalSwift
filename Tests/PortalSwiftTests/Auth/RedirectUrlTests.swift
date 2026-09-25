//
//  RedirectUrlTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers `RedirectUrl`, the hand-rolled deep-link helpers every Client Auth completion runs
/// through.
///
/// These functions decide whether an inbound deep link is *the* redirect the host registered
/// with Portal, and then hand the grant token out of its query string — so they are reachable
/// by any app that can open a URL. Three properties are pinned here rather than left to
/// `URLComponents`: matching is normalising but never *decoding* (so `callb%61ck` must not
/// match `callback`, and userinfo in the authority must not match a bare host), parsing never
/// throws on hostile input (a malformed escape comes back raw), and every path stays linear
/// (a 200,000-character run of slashes or ampersands finishes well inside the 2 s bound rather
/// than backtracking like the regex these functions deliberately avoid).
///
/// The cases are ported from the Android, React Native and Web suites so the four SDKs agree
/// character for character on what counts as a match and what a query parameter decodes to.
final class RedirectUrlTests: XCTestCase {
  /// The redirect a host registers with Portal, shared with the rest of the auth suite so a
  /// change to the canonical fixture is felt everywhere at once.
  private let configured = AuthTestFixtures.redirectUrl

  /// The short custom-scheme redirect the ported Android/RN cases are written against.
  private let myapp = "myapp://auth/callback"

  /// The length used by every adversarial-input case: large enough that a quadratic
  /// implementation would blow the 2 s bound, small enough to build in microseconds.
  private let hostileLength = 200_000

  /// Records everything the SDK logs so the security cases can prove these helpers stay
  /// silent — a deep link carries the grant token, and nothing here may echo it.
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - matchesRedirectUrl

  func test_matchesRedirectUrl_willMatchCustomSchemeWithQuery() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl(
        "portalexample://auth/callback?token=grant&authMethod=EMAIL_MAGIC_LINK",
        "portalexample://auth/callback"
      ),
      "A custom-scheme redirect carrying the grant query must match the configured redirect."
    )
  }

  func test_matchesRedirectUrl_willMatchUniversalLink() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl(
        "https://example.com/auth/callback?token=grant",
        "https://example.com/auth/callback"
      ),
      "A Universal Link redirect must match the configured https redirect."
    )
  }

  func test_matchesRedirectUrl_willIgnoreTrailingSlashesOnEitherSide() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("\(self.myapp)/", self.myapp),
      "A trailing slash on the incoming URL must not defeat the match."
    )
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl(self.myapp, "\(self.myapp)///"),
      "Trailing slashes on the configured redirect must not defeat the match."
    )
  }

  func test_matchesRedirectUrl_willLowercaseSchemeAndAuthorityButNotPath() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("MyApp://AUTH/callback", self.myapp),
      "The scheme and authority are case-insensitive per RFC 3986."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("myapp://auth/Callback", self.myapp),
      "The path is case-sensitive; `/Callback` is a different resource from `/callback`."
    )
    self.assertNothingLogged()
  }

  func test_matchesRedirectUrl_willIgnoreFragment() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("\(self.myapp)#state=xyz", self.myapp),
      "A fragment is never sent to a server and must not affect the match."
    )
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("\(self.myapp)?token=t#x", self.myapp),
      "A query and a fragment together must both be stripped before comparing."
    )
  }

  func test_matchesRedirectUrl_willRejectDifferentHostPathOrScheme() {
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("myapp://other/callback", self.myapp),
      "A different authority must not match."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("myapp://auth/other", self.myapp),
      "A different path must not match."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("otherapp://auth/callback", self.myapp),
      "A different custom scheme must not match."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("http://app.test/auth/callback", "https://app.test/auth/callback"),
      "Downgrading https to http must not match: the grant would travel in the clear."
    )
    self.assertNothingLogged()
  }

  func test_matchesRedirectUrl_willRejectDifferentPort() {
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("https://app.test:8443/auth/callback", "https://app.test/auth/callback"),
      "The port is part of the authority; a different origin must not match."
    )
    self.assertNothingLogged()
  }

  func test_matchesRedirectUrl_willRejectPathPrefixAndDeeperPath() {
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("https://app.test/auth", "https://app.test/auth/callback"),
      "A prefix of the configured path must not match."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("https://app.test/auth/callback/extra", "https://app.test/auth/callback"),
      "A deeper path under the configured redirect must not match."
    )
    self.assertNothingLogged()
  }

  func test_matchesRedirectUrl_willRejectUserinfoInAuthority() {
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("myapp://evil@auth/callback", self.myapp),
      "Userinfo is part of the authority: `evil@auth` is not the registered `auth`."
    )
    self.assertNothingLogged()
  }

  func test_matchesRedirectUrl_willNotDecodePercentEncodingInPath() {
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("myapp://auth/callb%61ck", self.myapp),
      "The path is compared byte-exact; decoding it would let `%61` impersonate `a`."
    )
    self.assertNothingLogged()
  }

  func test_matchesRedirectUrl_willHandleSchemeWithoutAuthority() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("myapp:auth?token=grant", "myapp:auth"),
      "A scheme written without `//` is a legal redirect and must still match."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("myapp:other", "myapp:auth"),
      "Without an authority the whole opaque part still has to be equal."
    )
  }

  func test_matchesRedirectUrl_willMatchSchemeOnlyTarget() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("myapp://?token=abc", "myapp://"),
      "A scheme-only redirect target matches any callback on that scheme."
    )
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("myapp://auth?token=abc", "myapp://auth"),
      "An authority with no path must match the same authority carrying a query."
    )
  }

  func test_matchesRedirectUrl_willMatchIgnoringQueryFragmentSlashAndCase_combined() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl(
        "HTTPS://App.Example.com/auth/callback/?token=abc#done",
        "https://app.example.com/auth/callback"
      ),
      "Query, fragment, trailing slash and scheme/host casing must all normalise at once."
    )
  }

  func test_matchesRedirectUrl_willNormalizeAllSlashTargetToEmpty() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("////////", ""),
      "A run of slashes normalises to the empty string, like the other SDKs."
    )
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("/", "//"),
      "This is a property of the helper only; PortalAuth rejects a blank redirectUrl earlier."
    )
  }

  func test_matchesRedirectUrl_willRejectUnparseableOrEmptyIncoming() {
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("not a url", self.configured),
      "An unparseable incoming URL must not match."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl(self.configured, "not a url"),
      "An unparseable configured redirect must not match."
    )
    XCTAssertFalse(
      RedirectUrl.matchesRedirectUrl("", self.configured),
      "An empty incoming URL must not match a configured redirect."
    )
  }

  func test_matchesRedirectUrl_willTrimSurroundingWhitespace() {
    XCTAssertTrue(
      RedirectUrl.matchesRedirectUrl("  \(self.myapp)\n", self.myapp),
      "Whitespace picked up from a pasteboard or a plist must be trimmed before comparing."
    )
  }

  func test_matchesRedirectUrl_willCompleteWithin2s_onHostileSlashRun() async throws {
    let hostile = self.myapp + String(repeating: "/", count: self.hostileLength) + "x"
    let target = self.myapp

    let matched = try await AuthTestFixtures.withTimeout(2) {
      RedirectUrl.matchesRedirectUrl(hostile, target)
    }

    let result = try XCTUnwrap(matched, "matchesRedirectUrl did not finish within 2 s on a hostile slash run.")
    XCTAssertFalse(result, "A slash run that does not end the string leaves the path different.")
  }

  func test_matchesRedirectUrl_willCompleteWithin2s_onPureSlashRun() async throws {
    let hostile = self.myapp + String(repeating: "/", count: self.hostileLength)
    let target = self.myapp

    let matched = try await AuthTestFixtures.withTimeout(2) {
      RedirectUrl.matchesRedirectUrl(hostile, target)
    }

    let result = try XCTUnwrap(matched, "matchesRedirectUrl did not finish within 2 s on a pure slash run.")
    XCTAssertTrue(result, "Every trailing slash is stripped in one linear pass, so this is still the redirect.")
  }

  // MARK: - normalizeRedirectTarget

  func test_normalizeRedirectTarget_willDropFragmentThenQuery() {
    XCTAssertEqual(
      RedirectUrl.normalizeRedirectTarget("a://b/c?x=1#f"),
      "a://b/c",
      "The fragment and then the query must both be dropped."
    )
    XCTAssertEqual(
      RedirectUrl.normalizeRedirectTarget("a://b/c#f?x=1"),
      "a://b/c",
      "A `?` inside the fragment is part of the fragment, not a query."
    )
  }

  func test_normalizeRedirectTarget_willLowercaseSchemeAndAuthorityOnly() {
    XCTAssertEqual(
      RedirectUrl.normalizeRedirectTarget("MyApp://AUTH/CallBack"),
      "myapp://auth/CallBack",
      "The scheme and authority lowercase; the path keeps its case."
    )
  }

  func test_normalizeRedirectTarget_willLowercaseWhole_whenNoAuthority() {
    XCTAssertEqual(
      RedirectUrl.normalizeRedirectTarget("MyApp:Auth"),
      "myapp:auth",
      "Without `://` there is no path to protect, so the whole string lowercases."
    )
  }

  func test_normalizeRedirectTarget_willHandleAuthorityWithoutPath() {
    XCTAssertEqual(
      RedirectUrl.normalizeRedirectTarget("MyApp://AUTH"),
      "myapp://auth",
      "An authority with no path must normalise without dropping or adding a separator."
    )
  }

  // MARK: - stripTrailingSlashes

  func test_stripTrailingSlashes_willStripAll() {
    XCTAssertEqual(RedirectUrl.stripTrailingSlashes("abc///"), "abc", "Every trailing slash is removed, not just one.")
  }

  func test_stripTrailingSlashes_willReturnEmpty_forEmptyOrAllSlashes() {
    XCTAssertEqual(RedirectUrl.stripTrailingSlashes(""), "", "An empty string is returned unchanged.")
    XCTAssertEqual(RedirectUrl.stripTrailingSlashes("///"), "", "A string of only slashes strips to empty.")
    XCTAssertEqual(RedirectUrl.stripTrailingSlashes("abc"), "abc", "A string with no trailing slash is untouched.")
  }

  // MARK: - parseQueryParams

  func test_parseQueryParams_willReturnEmpty_whenNoQuery() {
    XCTAssertEqual(RedirectUrl.parseQueryParams(self.myapp), [:], "A URL with no `?` has no parameters.")
    XCTAssertEqual(RedirectUrl.parseQueryParams("myapp://x?"), [:], "An empty query string yields no parameters.")
  }

  func test_parseQueryParams_willParseKeysAndValues() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?token=grant&authMethod=EMAIL_MAGIC_LINK"),
      ["token": "grant", "authMethod": "EMAIL_MAGIC_LINK"],
      "Both keys and both values must be read exactly."
    )
  }

  func test_parseQueryParams_willIgnoreQuestionMarkInFragment() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("\(self.myapp)#recovery?token=grant"),
      [:],
      "A `?` after a `#` belongs to the fragment; reading it would accept a token the server never sent."
    )
  }

  func test_parseQueryParams_willStopAtFragment() {
    let params = RedirectUrl.parseQueryParams("?token=grant#extra=ignored")

    XCTAssertEqual(params["token"], "grant", "The real query parameter is still read.")
    XCTAssertNil(params["extra"], "Nothing after the `#` is a query parameter.")
  }

  func test_parseQueryParams_willPercentDecodeAndPlusToSpace() {
    let params = RedirectUrl.parseQueryParams("?email=user%40example.com&name=Ada+L&tok=a%2Bb&empty=")

    XCTAssertEqual(params["email"], "user@example.com", "Percent escapes decode as UTF-8.")
    XCTAssertEqual(params["name"], "Ada L", "`+` decodes to a space, matching the other SDKs.")
    XCTAssertEqual(params["tok"], "a+b", "An encoded `%2B` decodes to a literal plus, not a space.")
    XCTAssertEqual(params["empty"], "", "A key with an empty value is present with an empty string.")
  }

  func test_parseQueryParams_willDecodeUnicode() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?n=%C3%A9")["n"],
      "é",
      "Multi-byte UTF-8 sequences decode across the escapes that carry them."
    )
  }

  func test_parseQueryParams_willReturnUndecodableValueRaw() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?token=%E0%A4%A")["token"],
      "%E0%A4%A",
      "A truncated escape is returned raw rather than throwing or dropping the parameter."
    )
  }

  func test_parseQueryParams_willReturnUndecodableValueWithPlusAsSpace() {
    // PLAN 9.5 inverts the original matrix expectation: when the percent decode fails the
    // ORIGINAL value is returned (Android semantics), not the plus-substituted intermediate.
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?token=%E0%A4%A+x")["token"],
      "%E0%A4%A+x",
      "A failed decode returns the untouched original, so the `+` is not turned into a space."
    )
  }

  func test_parseQueryParams_willTreatKeyWithoutEqualsAsEmpty() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?token"),
      ["token": ""],
      "A valueless key is present with an empty value, so a caller can tell it apart from a missing key."
    )
  }

  func test_parseQueryParams_willLetLastOccurrenceWin() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?token=configured&token=live-grant")["token"],
      "live-grant",
      "The backend appends its parameters, so the last `token` is the live grant."
    )
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?token=a&token=")["token"],
      "",
      "Last-wins holds even when the last occurrence is empty."
    )
  }

  func test_parseQueryParams_willSkipEmptyPairsAndEmptyKeys() {
    let padded = RedirectUrl.parseQueryParams("?&token=grant&&")
    XCTAssertEqual(padded.count, 1, "Empty pairs contribute nothing.")
    XCTAssertEqual(padded["token"], "grant", "The real parameter survives the empty pairs.")

    let emptyKey = RedirectUrl.parseQueryParams("?=value&token=g")
    XCTAssertEqual(emptyKey.count, 1, "A pair with an empty key is skipped.")
    XCTAssertEqual(emptyKey["token"], "g", "The named parameter is still read.")
  }

  func test_parseQueryParams_willDecodePercentEncodedKey() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?tok%65n=grant"),
      ["token": "grant"],
      "Keys decode like values, so an encoded key still resolves to the name the caller reads."
    )
  }

  func test_parseQueryParams_willKeepEqualsInsideValue() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?token=a=b")["token"],
      "a=b",
      "Only the first `=` separates key from value; a base64 grant can contain more."
    )
  }

  func test_parseQueryParams_willTreatSecondQuestionMarkAsValue() {
    XCTAssertEqual(
      RedirectUrl.parseQueryParams("?a=1?b=2"),
      ["a": "1?b=2"],
      "Only the first `?` opens the query; a later one is an ordinary value character."
    )
  }

  func test_parseQueryParams_willHandleRedirectOwnQueryAndCustomScheme() {
    let universal = RedirectUrl.parseQueryParams("https://app.test/callback?env=prod&token=grant&login_type=APPLE")
    XCTAssertEqual(universal["env"], "prod", "A redirect that already carries its own query keeps it.")
    XCTAssertEqual(universal["token"], "grant", "The appended grant is read alongside the host's own parameters.")
    XCTAssertEqual(universal["login_type"], "APPLE", "The provider parameter is read verbatim off the wire.")

    XCTAssertEqual(
      RedirectUrl.parseQueryParams("\(self.myapp)?token=grant")["token"],
      "grant",
      "A custom scheme parses the same way as a Universal Link."
    )
  }

  func test_parseQueryParams_willCompleteWithin2s_onHostileAmpersandRun() async throws {
    let hostile = "myapp://x?" + String(repeating: "&", count: self.hostileLength) + "token=g"

    let parsed = try await AuthTestFixtures.withTimeout(2) {
      RedirectUrl.parseQueryParams(hostile)
    }

    let params = try XCTUnwrap(parsed, "parseQueryParams did not finish within 2 s on a hostile ampersand run.")
    XCTAssertEqual(params, ["token": "g"], "Empty pairs are skipped in one linear pass.")
  }

  func test_parseQueryParams_willCompleteWithin2s_onHugeValue() async throws {
    let hostile = "?token=" + String(repeating: "%41", count: self.hostileLength)
    let expected = String(repeating: "A", count: self.hostileLength)

    let parsed = try await AuthTestFixtures.withTimeout(2) {
      RedirectUrl.parseQueryParams(hostile)
    }

    let params = try XCTUnwrap(parsed, "parseQueryParams did not finish within 2 s on a huge value.")
    XCTAssertEqual(params["token"], expected, "Every escape decodes, in one pass over the bytes.")
  }

  // MARK: - decodeComponent

  func test_decodeComponent_willDecodeVectors() {
    XCTAssertEqual(RedirectUrl.decodeComponent("a%20b"), "a b", "`%20` decodes to a space.")
    XCTAssertEqual(RedirectUrl.decodeComponent("a+b"), "a b", "`+` decodes to a space.")
    XCTAssertEqual(RedirectUrl.decodeComponent(""), "", "An empty component decodes to empty.")
  }

  func test_decodeComponent_willReturnRaw_onMalformedEscapes() {
    XCTAssertEqual(RedirectUrl.decodeComponent("%zz"), "%zz", "A non-hex escape returns the original.")
    XCTAssertEqual(RedirectUrl.decodeComponent("%"), "%", "A dangling `%` returns the original.")
    XCTAssertEqual(RedirectUrl.decodeComponent("100%"), "100%", "A trailing `%` returns the original.")
    XCTAssertEqual(RedirectUrl.decodeComponent("%E0%A4%A"), "%E0%A4%A", "A truncated escape returns the original.")
    XCTAssertEqual(
      RedirectUrl.decodeComponent("%zz+x"),
      "%zz+x",
      "A failure returns the untouched original, so a `+` already substituted is put back."
    )
  }

  // MARK: - customScheme

  func test_customScheme_willReturnLowercasedScheme() {
    XCTAssertEqual(
      RedirectUrl.customScheme(of: "portalexample://auth/callback"),
      "portalexample",
      "ASWebAuthenticationSession is handed the scheme alone."
    )
    XCTAssertEqual(
      RedirectUrl.customScheme(of: "PortalExample://auth/callback"),
      "portalexample",
      "Schemes are case-insensitive, and the system matches the lowercased form."
    )
  }

  func test_customScheme_willReturnNil_forHttpAndHttps() {
    XCTAssertNil(RedirectUrl.customScheme(of: "https://example.com/cb"), "A Universal Link has no custom scheme.")
    XCTAssertNil(RedirectUrl.customScheme(of: "http://example.com/cb"), "http is not a callback scheme either.")
    XCTAssertNil(RedirectUrl.customScheme(of: "HTTPS://x"), "The http/https check happens after lowercasing.")
  }

  func test_customScheme_willReturnNil_whenNoColon() {
    XCTAssertNil(RedirectUrl.customScheme(of: "noscheme/path"), "Without a `:` there is no scheme.")
    XCTAssertNil(RedirectUrl.customScheme(of: ""), "An empty redirect has no scheme.")
    XCTAssertNil(RedirectUrl.customScheme(of: "   "), "A blank redirect trims to empty and has no scheme.")
  }

  func test_customScheme_willAcceptDigitsPlusMinusDot() {
    XCTAssertEqual(RedirectUrl.customScheme(of: "com.example.app://cb"), "com.example.app", "Dots are legal in a scheme.")
    XCTAssertEqual(RedirectUrl.customScheme(of: "app+v2://x"), "app+v2", "`+` is legal in a scheme.")
    XCTAssertEqual(RedirectUrl.customScheme(of: "my-app://x"), "my-app", "`-` is legal in a scheme.")
    XCTAssertEqual(RedirectUrl.customScheme(of: "app2://x"), "app2", "Digits after the first character are legal.")
  }

  func test_customScheme_willReturnNil_forInvalidSchemeChars() {
    XCTAssertNil(RedirectUrl.customScheme(of: "2app://x"), "RFC 3986 requires the first character to be a letter.")
    XCTAssertNil(RedirectUrl.customScheme(of: ":foo"), "An empty scheme is not a scheme.")
    XCTAssertNil(RedirectUrl.customScheme(of: "my app://x"), "A space is not a legal scheme character.")
    XCTAssertNil(RedirectUrl.customScheme(of: "my/app://x"), "A `/` before the `:` means this is a path, not a scheme.")
    self.assertNothingLogged()
  }

  func test_customScheme_willReturnScheme_withoutAuthority() {
    XCTAssertEqual(RedirectUrl.customScheme(of: "myapp:auth"), "myapp", "A scheme written without `//` still registers.")
    XCTAssertEqual(RedirectUrl.customScheme(of: "myapp://"), "myapp", "A scheme-only redirect yields its scheme.")
  }

  // MARK: - Helpers

  /// Fails the test if these helpers logged anything.
  ///
  /// `RedirectUrl` runs over attacker-reachable input that carries the grant token, so the
  /// correct amount of logging from it is none at all — asserting through the recorder's sink
  /// (which sees every level regardless of `logLevel`) keeps that from regressing silently.
  private func assertNothingLogged(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(
      self.logger.messages.isEmpty,
      "RedirectUrl must not log; it logged: \(self.logger.messages)",
      file: file,
      line: line
    )
  }
}

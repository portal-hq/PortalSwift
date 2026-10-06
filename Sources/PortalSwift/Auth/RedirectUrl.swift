//
//  RedirectUrl.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// URL helpers for the redirect that ends every Client Auth flow.
///
/// Hand-rolled rather than built on `URLComponents` for two reasons. A redirect can be a
/// custom scheme (`portalexample://auth/callback`) or a Universal Link, and both have to
/// normalise the same way — `URLComponents` treats `myapp://` and `myapp:` differently and
/// percent-decodes paths, which would let `callb%61ck` match `callback`. And these functions
/// must never throw and must stay linear on adversarial input, since a deep link is reachable
/// by any installed app: no regular expressions (a `/\/+$/` pattern is quadratic on a long run
/// of slashes) and no `queryItems` (which decodes differently from the other Portal SDKs).
enum RedirectUrl {
  private static let authoritySeparator = "://"

  // MARK: - Matching

  /// Strips every trailing `/`.
  ///
  /// An index walk from the end rather than a regex or repeated `dropLast`, so a run of
  /// 200,000 slashes costs one pass and no intermediate allocations.
  static func stripTrailingSlashes(_ value: String) -> String {
    var end = value.endIndex
    while end > value.startIndex {
      let previous = value.index(before: end)
      guard value[previous] == "/" else {
        break
      }
      end = previous
    }

    return end == value.endIndex ? value : String(value[..<end])
  }

  /// Normalises a URL for comparison: fragment dropped, then query dropped, surrounding
  /// whitespace trimmed, trailing slashes removed, scheme and authority lowercased.
  ///
  /// The path keeps its case deliberately — hosts are case-insensitive per RFC 3986, paths
  /// are not — so `myapp://auth/Callback` does not match a redirect registered as
  /// `myapp://auth/callback`. A string without `://` (a scheme written without an authority,
  /// or something that is not a URL at all) has nothing to case-normalise separately and is
  /// lowercased whole.
  static func normalizeRedirectTarget(_ url: String) -> String {
    var target = Substring(url)
    if let hash = target.firstIndex(of: "#") {
      target = target[..<hash]
    }
    if let question = target.firstIndex(of: "?") {
      target = target[..<question]
    }

    let trimmed = self.stripTrailingSlashes(target.trimmingCharacters(in: .whitespacesAndNewlines))

    guard let separator = trimmed.range(of: self.authoritySeparator),
          separator.lowerBound > trimmed.startIndex
    else {
      return trimmed.lowercased()
    }

    let afterAuthority = trimmed[separator.upperBound...]
    let pathStart = afterAuthority.firstIndex(of: "/") ?? trimmed.endIndex

    return trimmed[..<pathStart].lowercased() + trimmed[pathStart...]
  }

  /// `true` when `url` targets `redirectUrl`, ignoring query string, fragment, trailing
  /// slashes, surrounding whitespace, and scheme/authority case.
  static func matchesRedirectUrl(_ url: String, _ redirectUrl: String) -> Bool {
    self.normalizeRedirectTarget(url) == self.normalizeRedirectTarget(redirectUrl)
  }

  // MARK: - Query parsing

  /// Parses the query string of `url` into a dictionary.
  ///
  /// The fragment is removed first (a `?` after a `#` belongs to the fragment), pairs are
  /// split on `&`, empty pairs and empty keys are skipped, and the **last** occurrence of a
  /// key wins: the backend appends its parameters to the configured `redirectUrl`, so if that
  /// URL already carries a `token`, the appended one is the live grant. Values that fail to
  /// decode are returned raw rather than dropped — a malformed parameter is not this
  /// function's call to reject, and the caller validates every value it reads anyway.
  static func parseQueryParams(_ url: String) -> [String: String] {
    var target = Substring(url)
    if let hash = target.firstIndex(of: "#") {
      target = target[..<hash]
    }
    guard let question = target.firstIndex(of: "?") else {
      return [:]
    }

    let query = target[target.index(after: question)...]
    var params: [String: String] = [:]

    for pair in query.split(separator: "&", omittingEmptySubsequences: true) {
      let rawKey: Substring
      let rawValue: Substring
      if let equals = pair.firstIndex(of: "=") {
        rawKey = pair[..<equals]
        rawValue = pair[pair.index(after: equals)...]
      } else {
        rawKey = pair
        rawValue = pair[pair.endIndex...]
      }

      let key = self.decodeComponent(String(rawKey))
      guard !key.isEmpty else {
        continue
      }

      params[key] = self.decodeComponent(String(rawValue))
    }

    return params
  }

  /// Decodes one query component: `+` becomes a space, then percent-escapes are decoded as
  /// UTF-8.
  ///
  /// When decoding fails — a malformed escape such as `%zz` or a dangling `%`, or bytes that
  /// are not valid UTF-8 — the **original** value is returned untouched (Android semantics),
  /// not the plus-substituted intermediate. Hand-rolled over the UTF-8 bytes so the cost is
  /// one linear pass and the failure behaviour does not depend on Foundation's version.
  static func decodeComponent(_ value: String) -> String {
    let input = Array(value.utf8)
    var output: [UInt8] = []
    output.reserveCapacity(input.count)
    var changed = false
    var index = 0

    while index < input.count {
      let byte = input[index]
      if byte == UInt8(ascii: "+") {
        output.append(UInt8(ascii: " "))
        changed = true
        index += 1
      } else if byte == UInt8(ascii: "%") {
        guard index + 2 < input.count,
              let high = self.hexValue(input[index + 1]),
              let low = self.hexValue(input[index + 2])
        else {
          return value
        }
        output.append(high << 4 | low)
        changed = true
        index += 3
      } else {
        output.append(byte)
        index += 1
      }
    }

    guard changed else {
      return value
    }
    guard let decoded = String(bytes: output, encoding: .utf8) else {
      return value
    }
    return decoded
  }

  // MARK: - Scheme

  /// The lowercased custom URL scheme of `redirectUrl`, or `nil` when it has none.
  ///
  /// `signInWithGoogle()` / `signInWithApple()` hand this to `ASWebAuthenticationSession` as
  /// the `callbackURLScheme`, which only supports custom schemes — so `http`/`https` (Universal
  /// Links) return `nil` and the sign-in surfaces `PortalAuthSignInError.unavailable`. The
  /// scheme must satisfy RFC 3986 (`ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`); anything else
  /// is not a scheme the system would ever call back on.
  static func customScheme(of redirectUrl: String) -> String? {
    let trimmed = redirectUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let colon = trimmed.firstIndex(of: ":") else {
      return nil
    }

    let scheme = trimmed[..<colon]
    var scalars = scheme.unicodeScalars.makeIterator()
    guard let first = scalars.next(), self.isAsciiLetter(first) else {
      return nil
    }
    while let scalar = scalars.next() {
      guard self.isAsciiLetter(scalar) || self.isAsciiDigit(scalar) || scalar == "+" || scalar == "-" || scalar == "." else {
        return nil
      }
    }

    let lowercased = scheme.lowercased()
    guard lowercased != "http", lowercased != "https" else {
      return nil
    }
    return lowercased
  }

  // MARK: - Private helpers

  private static func hexValue(_ byte: UInt8) -> UInt8? {
    switch byte {
    case UInt8(ascii: "0") ... UInt8(ascii: "9"):
      return byte - UInt8(ascii: "0")
    case UInt8(ascii: "a") ... UInt8(ascii: "f"):
      return byte - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A") ... UInt8(ascii: "F"):
      return byte - UInt8(ascii: "A") + 10
    default:
      return nil
    }
  }

  private static func isAsciiLetter(_ scalar: Unicode.Scalar) -> Bool {
    ("a" ... "z").contains(scalar) || ("A" ... "Z").contains(scalar)
  }

  private static func isAsciiDigit(_ scalar: Unicode.Scalar) -> Bool {
    ("0" ... "9").contains(scalar)
  }
}

//
//  TotpQrCode.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
#if canImport(UIKit)
  import UIKit
#endif

// MARK: - Public API

public extension TotpRequiredResult {
  /// The shared secret inside `totpLink`, ready to be typed into an authenticator app, or
  /// `nil` when the link carries no usable secret.
  ///
  /// The SDK reads the link rather than asking the host to parse an `otpauth://` URI: the
  /// link is trimmed, percent-decoded as a whole when the backend delivered it encoded, and
  /// its `secret` query parameter (the last one, when repeated) is percent-decoded, trimmed
  /// and upper-cased. Only a value in the base32 alphabet (`A–Z`, `2–7`, optional trailing
  /// `=` padding) is returned, so a host can show it verbatim without a second validation.
  /// Anything else — a `nil` or blank link, a non-`otpauth://` scheme, a missing, empty or
  /// non-base32 secret, a bare secret with no URI — reads as `nil`.
  var totpSecret: String? {
    guard let totpLink = self.totpLink,
          let payload = TotpLink.normalized(totpLink)
    else {
      return nil
    }
    return TotpLink.secret(in: payload)
  }

  /// Renders `totpLink` as a QR code an authenticator app can scan.
  ///
  /// `scale` is the side of one QR module in pixels (default 10), so the image is
  /// `(modules + 8) × scale` pixels square: error-correction level "M", pure black modules on
  /// an opaque white background, nearest-neighbour scaling so every module stays crisp, and
  /// the 4-module quiet zone the QR specification requires. The payload encoded is the
  /// trimmed, decoded link exactly as `totpSecret` reads it.
  ///
  /// - Throws: `PortalAuthError.totpQrUnavailable` when `totpLink` is `nil`, blank, not an
  ///   `otpauth://` URI, carries no valid secret, when `scale` is not a finite number of at
  ///   least 1 (below one pixel per module the image cannot be scanned), or when the QR could
  ///   not be generated. The error never includes the link.
  func qrCodeImage(scale: CGFloat = 10) throws -> UIImage {
    guard let totpLink = self.totpLink else {
      throw PortalAuthError.totpQrUnavailable
    }
    return try portalTotpQrCodeImage(otpAuthUrl: totpLink, scale: scale)
  }
}

/// `TotpRequiredResult.qrCodeImage(scale:)` for hosts that hold the `otpauth://` link
/// themselves (a persisted enrolment link, a link received through another channel).
///
/// Identical output for an identical link: same payload normalisation, error-correction
/// level "M", pure black on opaque white, nearest-neighbour scaling, 4-module quiet zone,
/// `(modules + 8) × scale` pixels square.
///
/// - Throws: `PortalAuthError.totpQrUnavailable` when the link is blank, not an `otpauth://`
///   URI, carries no valid secret, when `scale` is not a finite number of at least 1, or when
///   the QR could not be generated. The error never includes the link.
public func portalTotpQrCodeImage(otpAuthUrl: String, scale: CGFloat = 10) throws -> UIImage {
  // At least one pixel per module: below that, nearest-neighbour sampling drops modules and the
  // image looks like a QR code but cannot be scanned — a silent failure worse than throwing.
  guard scale.isFinite, scale >= 1 else {
    throw PortalAuthError.totpQrUnavailable
  }
  guard let payload = totpQrPayload(otpAuthUrl) else {
    throw PortalAuthError.totpQrUnavailable
  }
  guard let grid = TotpQrRenderer.moduleGrid(for: payload, correctionLevel: TotpQrRenderer.correctionLevel),
        let cgImage = TotpQrRenderer.render(grid, scale: scale)
  else {
    throw PortalAuthError.totpQrUnavailable
  }
  return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
}

// MARK: - Internal helpers (test seams)

/// The exact string the QR encodes for `link`, or `nil` when the link is not scannable.
///
/// Scannable means: non-blank after trimming, an `otpauth://` scheme (case-insensitive; a
/// link percent-encoded as a whole is decoded first), and a `secret` parameter that
/// `TotpRequiredResult.totpSecret` accepts. The returned payload is the trimmed, decoded link
/// — never re-encoded, so an already-decoded link is returned untouched.
func totpQrPayload(_ link: String) -> String? {
  guard let payload = TotpLink.normalized(link), TotpLink.secret(in: payload) != nil else {
    return nil
  }
  return payload
}

/// The number of modules on one side of the QR symbol CoreImage produces for `payload` at
/// `correctionLevel` ("L", "M", "Q" or "H"), excluding any quiet zone, or `nil` when
/// CoreImage yields no usable symbol. `21` for a version-1 symbol, `177` for version 40.
func qrModuleCount(for payload: String, correctionLevel: String) -> Int? {
  TotpQrRenderer.moduleGrid(for: payload, correctionLevel: correctionLevel)?.size
}

// MARK: - Link parsing

/// Hand-rolled `otpauth://` link handling: linear scans over the string, no regular
/// expressions and no `URLComponents`, so a hostile 200k-character link is rejected in
/// milliseconds instead of backtracking.
enum TotpLink {
  private static let scheme = "otpauth://"
  private static let secretParameter = "secret"

  /// Trims `link` and, when the trimmed value does not already start with `otpauth://`,
  /// percent-decodes it as a whole in case the backend delivered the link encoded. Returns
  /// `nil` unless the result carries the `otpauth://` scheme.
  static func normalized(_ link: String) -> String? {
    let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    if self.hasScheme(trimmed) {
      return trimmed
    }

    guard let decoded = trimmed.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
          self.hasScheme(decoded)
    else {
      return nil
    }
    return decoded
  }

  /// The validated, upper-cased `secret` parameter of an already-normalised link, or `nil`.
  ///
  /// The fragment is dropped first, then the query is split on `&`; the last `secret` wins
  /// (the same "last occurrence wins" rule the redirect parser applies); the value is
  /// percent-decoded (an undecodable value is used raw), trimmed and upper-cased; only a
  /// base32 value with at least one data character survives.
  static func secret(in link: String) -> String? {
    var candidate: Substring?
    for (name, value) in self.queryPairs(of: link) where self.decodedName(name) == self.secretParameter {
      candidate = value
    }

    guard let raw = candidate else {
      return nil
    }
    let decoded = String(raw).removingPercentEncoding ?? String(raw)
    return self.normalizedSecret(decoded)
  }

  /// Case-insensitive, allocation-free check of the first ten bytes against `otpauth://`.
  private static func hasScheme(_ value: String) -> Bool {
    var bytes = value.utf8.makeIterator()
    for expected in self.scheme.utf8 {
      guard let byte = bytes.next() else {
        return false
      }
      let lowered = (byte >= 0x41 && byte <= 0x5A) ? byte + 0x20 : byte
      guard lowered == expected else {
        return false
      }
    }
    return true
  }

  /// `(name, value)` for every `name=value` pair in the query of `link`; pairs without `=`
  /// are skipped. The fragment is removed before the query is located so a `?` inside the
  /// fragment is never mistaken for the query start.
  private static func queryPairs(of link: String) -> [(Substring, Substring)] {
    var body = Substring(link)
    if let hash = body.firstIndex(of: "#") {
      body = body[..<hash]
    }
    guard let questionMark = body.firstIndex(of: "?") else {
      return []
    }
    let query = body[body.index(after: questionMark)...]

    var pairs: [(Substring, Substring)] = []
    for pair in query.split(separator: "&", omittingEmptySubsequences: true) {
      guard let equals = pair.firstIndex(of: "=") else {
        continue
      }
      pairs.append((pair[..<equals], pair[pair.index(after: equals)...]))
    }
    return pairs
  }

  private static func decodedName(_ name: Substring) -> String {
    guard name.contains("%") else {
      return String(name)
    }
    return String(name).removingPercentEncoding ?? String(name)
  }

  /// Trims and upper-cases `value`; returns it only when it is base32 (`A–Z`, `2–7`) with
  /// optional trailing `=` padding and at least one data character.
  private static func normalizedSecret(_ value: String) -> String? {
    let upper = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    var dataCharacters = 0
    var sawPadding = false

    for byte in upper.utf8 {
      if byte == UInt8(ascii: "=") {
        sawPadding = true
        continue
      }
      guard !sawPadding else {
        return nil
      }
      let isUpperLetter = byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")
      let isBase32Digit = byte >= UInt8(ascii: "2") && byte <= UInt8(ascii: "7")
      guard isUpperLetter || isBase32Digit else {
        return nil
      }
      dataCharacters += 1
    }

    guard dataCharacters > 0 else {
      return nil
    }
    return upper
  }
}

// MARK: - Rendering

/// CoreImage-backed QR rendering with pixel-exact output.
///
/// `CIQRCodeGenerator` is used only to compute the symbol: its output is rendered once at
/// module resolution through `CIFalseColor` (pure black on pure white) into a bitmap, and the
/// symbol is located as the bounding box of the dark modules — the finder patterns guarantee
/// dark modules at the symbol's corners, and this sidesteps the one-module border CoreImage
/// adds around the symbol, whose width is not documented. The final image is then written
/// pixel by pixel by nearest-neighbour lookup into an opaque RGBA8 bitmap, so every pixel is
/// exactly black or white whatever the display colour space, the quiet zone is exactly four
/// modules, and the same link always yields the same bytes. The shared `CIContext` is
/// immutable and safe to use from concurrent calls.
enum TotpQrRenderer {
  /// Error-correction level "M" (~15% recovery): the cross-SDK choice for enrolment QRs.
  static let correctionLevel = "M"

  /// The quiet zone the QR specification requires, in modules, on every side.
  static let quietZoneModules = 4

  /// Upper bound on the rendered image side, in pixels, so an absurd `scale` fails with
  /// `totpQrUnavailable` instead of an out-of-memory crash.
  static let maxImageSide = 8192

  /// Upper bound on the module-resolution render CoreImage may hand back (version 40 is 177
  /// modules plus CoreImage's border); anything larger is not a QR symbol.
  private static let maxSymbolRenderSide = 1024

  /// Smallest and largest QR symbol sides (versions 1 and 40).
  private static let minSymbolSize = 21
  private static let maxSymbolSize = 177

  /// Colour management disabled: the filter output is consumed as data, not displayed.
  private static let context = CIContext(options: [
    .workingColorSpace: NSNull(),
    .outputColorSpace: NSNull()
  ])

  /// A QR symbol as a square grid of modules, row-major, top row first.
  struct ModuleGrid {
    let size: Int
    let dark: [Bool]

    func isDark(row: Int, column: Int) -> Bool {
      self.dark[row * self.size + column]
    }
  }

  /// The symbol CoreImage generates for `payload` at `correctionLevel`, or `nil` when it
  /// yields nothing, or something that is not a square QR symbol of a valid version.
  static func moduleGrid(for payload: String, correctionLevel: String) -> ModuleGrid? {
    let generator = CIFilter.qrCodeGenerator()
    generator.message = Data(payload.utf8)
    generator.correctionLevel = correctionLevel
    guard let symbol = generator.outputImage else {
      return nil
    }

    let recolor = CIFilter.falseColor()
    recolor.inputImage = symbol
    recolor.color0 = CIColor(red: 0, green: 0, blue: 0)
    recolor.color1 = CIColor(red: 1, green: 1, blue: 1)
    guard let colored = recolor.outputImage else {
      return nil
    }

    let extent = colored.extent.integral
    let width = Int(extent.width)
    let height = Int(extent.height)
    guard width > 0, height > 0, width <= self.maxSymbolRenderSide, height <= self.maxSymbolRenderSide,
          let cgImage = self.context.createCGImage(colored, from: extent),
          let bitmap = self.readBitmap(cgImage, width: width, height: height)
    else {
      return nil
    }

    // Bounding box of the dark pixels: the symbol itself, whatever border surrounds it.
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0 ..< height {
      for x in 0 ..< width where bitmap.isDark(x: x, y: y) {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
      }
    }

    let size = maxX - minX + 1
    guard maxX >= minX, maxY >= minY,
          size == maxY - minY + 1,
          size >= self.minSymbolSize, size <= self.maxSymbolSize,
          (size - self.minSymbolSize) % 4 == 0
    else {
      return nil
    }

    var dark = [Bool](repeating: false, count: size * size)
    for row in 0 ..< size {
      for column in 0 ..< size {
        dark[row * size + column] = bitmap.isDark(x: minX + column, y: minY + row)
      }
    }
    return ModuleGrid(size: size, dark: dark)
  }

  /// Draws `grid` at `scale` pixels per module with a `quietZoneModules` white border into an
  /// opaque RGBA8 image, `((size + 8) × scale)` pixels square (rounded for a non-integer
  /// scale). Nearest-neighbour by construction: each output pixel looks up the module it
  /// falls in. Returns `nil` when the side is zero or exceeds `maxImageSide`.
  static func render(_ grid: ModuleGrid, scale: CGFloat) -> CGImage? {
    let totalModules = grid.size + 2 * self.quietZoneModules
    // Bounded in floating point *before* the integer conversion: `Int(_:)` traps on a value
    // outside its range, so a huge finite `scale` would have crashed here instead of returning
    // `nil` for the `maxImageSide` guard to report.
    let sidePixels = (CGFloat(totalModules) * scale).rounded()
    guard sidePixels >= 1, sidePixels <= CGFloat(self.maxImageSide) else {
      return nil
    }
    let side = Int(sidePixels)

    guard let bitmap = CGContext(
      data: nil,
      width: side,
      height: side,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ), let base = bitmap.data else {
      return nil
    }
    let bytesPerRow = bitmap.bytesPerRow
    let pixels = base.assumingMemoryBound(to: UInt8.self)
    memset(pixels, 0xFF, bytesPerRow * side)

    // Module index for each pixel coordinate, offset by the quiet zone; `nil` inside it.
    let moduleIndex: [Int?] = (0 ..< side).map { pixel in
      let module = Int(CGFloat(pixel) * CGFloat(totalModules) / CGFloat(side)) - self.quietZoneModules
      return (module >= 0 && module < grid.size) ? module : nil
    }

    for y in 0 ..< side {
      guard let row = moduleIndex[y] else {
        continue
      }
      let rowStart = y * bytesPerRow
      for x in 0 ..< side {
        guard let column = moduleIndex[x], grid.isDark(row: row, column: column) else {
          continue
        }
        let offset = rowStart + x * 4
        pixels[offset] = 0
        pixels[offset + 1] = 0
        pixels[offset + 2] = 0
      }
    }

    return bitmap.makeImage()
  }

  /// A module-resolution render of `cgImage`, thresholded on the red channel.
  private struct Bitmap {
    let width: Int
    let bytesPerRow: Int
    let bytes: [UInt8]

    func isDark(x: Int, y: Int) -> Bool {
      self.bytes[y * self.bytesPerRow + x * 4] < 0x80
    }
  }

  private static func readBitmap(_ cgImage: CGImage, width: Int, height: Int) -> Bitmap? {
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
      return nil
    }
    context.interpolationQuality = .none
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let base = context.data else {
      return nil
    }
    let bytesPerRow = context.bytesPerRow
    let count = bytesPerRow * height
    let bytes = [UInt8](UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: count))
    return Bitmap(width: width, bytesPerRow: bytesPerRow, bytes: bytes)
  }
}

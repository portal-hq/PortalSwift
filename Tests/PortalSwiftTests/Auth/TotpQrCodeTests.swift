//
//  TotpQrCodeTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
@testable import PortalSwift
import UIKit
import XCTest

// MARK: - Test helpers

/// One pixel of a generated QR image, alpha included, so "pure black or white, fully opaque"
/// is an assertion about all four channels rather than about luminance alone.
private struct SampledPixel: Equatable {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
  let alpha: UInt8

  static let black = SampledPixel(red: 0, green: 0, blue: 0, alpha: 255)
  static let white = SampledPixel(red: 255, green: 255, blue: 255, alpha: 255)

  var isDark: Bool {
    self.red < 128
  }
}

/// An RGBA8 render of a `UIImage`, read back pixel by pixel.
///
/// The bitmap is drawn into an *unprepared* premultiplied-RGBA context: nothing is filled in
/// first, so a pixel the QR image did not paint would read back as `(0, 0, 0, 0)` and fail the
/// opacity assertions instead of quietly inheriting a white background the test itself painted.
private struct PixelBuffer {
  let width: Int
  let height: Int
  private let bytesPerRow: Int
  private let bytes: [UInt8]

  init?(_ image: UIImage) {
    guard let cgImage = image.cgImage, cgImage.width > 0, cgImage.height > 0 else {
      return nil
    }
    let width = cgImage.width
    let height = cgImage.height
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
      return nil
    }
    context.interpolationQuality = .none
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let base = context.data else {
      return nil
    }

    self.width = width
    self.height = height
    self.bytesPerRow = context.bytesPerRow
    self.bytes = [UInt8](
      UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: context.bytesPerRow * height)
    )
  }

  /// The pixel at `(x, y)`, with `(0, 0)` at the corner the bitmap stores first.
  func pixel(_ x: Int, _ y: Int) -> SampledPixel {
    let offset = y * self.bytesPerRow + x * 4
    return SampledPixel(
      red: self.bytes[offset],
      green: self.bytes[offset + 1],
      blue: self.bytes[offset + 2],
      alpha: self.bytes[offset + 3]
    )
  }
}

/// Decodes a generated QR image the way an authenticator app would, through Vision's QR
/// detector, so the round-trip assertions prove the image is scannable and not merely
/// plausible-looking.
private func decodeQr(_ image: UIImage) -> String? {
  guard let ciImage = CIImage(image: image) else {
    return nil
  }
  let detector = CIDetector(
    ofType: CIDetectorTypeQRCode,
    context: nil,
    options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
  )
  let features = detector?.features(in: ciImage) ?? []
  return features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
}

/// The number of modules on one side of the symbol CoreImage generates for `payload`,
/// computed independently of the SDK from a reference `CIQRCodeGenerator` output.
///
/// `CIQRCodeGenerator` frames the symbol in a one-module border, so the symbol is the output
/// extent minus one module on each side. The result is validated against the QR versions
/// (21 + 4n modules, versions 1 to 40) so a change in that border shows up as a `nil` here
/// rather than as an off-by-two size expectation.
private func referenceModuleCount(for payload: String, correctionLevel: String) -> Int? {
  let generator = CIFilter.qrCodeGenerator()
  generator.message = Data(payload.utf8)
  generator.correctionLevel = correctionLevel
  guard let output = generator.outputImage else {
    return nil
  }

  let modules = Int(output.extent.integral.width) - 2
  guard modules >= 21, modules <= 177, (modules - 21) % 4 == 0 else {
    return nil
  }
  return modules
}

// MARK: - TotpQrCodeTests

/// Covers `TotpRequiredResult.totpSecret`, `TotpRequiredResult.qrCodeImage(scale:)` and the
/// free `portalTotpQrCodeImage(otpAuthUrl:scale:)`.
///
/// Two things are being pinned. First, the hand-rolled `otpauth://` reader: it accepts every
/// shape the backend and the other SDKs produce (percent-encoded labels, a link encoded as a
/// whole, an uppercase scheme, whitespace, padding, a duplicated parameter) and rejects
/// everything else — including a bare secret, which stays an example-app affordance — while
/// finishing a 200k-character hostile link in milliseconds because it never uses a regular
/// expression. Second, the rendered image: the exact pixel size implied by the module count
/// and `scale`, a four-module white quiet zone, pure black on pure white with no
/// anti-aliasing or transparency, error-correction level "M", and a payload that a real QR
/// decoder reads back byte for byte.
///
/// Module counts come from a reference `CIQRCodeGenerator` output rather than from the SDK, so
/// a size assertion cannot be satisfied by the code that produced the image. The image is read
/// back through `CIDetector` and through a raw RGBA8 render. A `RecordingLogger` is installed
/// for every case because the `totpLink` embeds the TOTP secret and must never reach a log.
final class TotpQrCodeTests: XCTestCase {
  /// A valid base32 secret, long enough that the symbol needs a real QR version.
  private static let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
  /// The enrollment link shape the backend sends.
  private static let link = "otpauth://totp/Portal:user@example.com?secret=\(TotpQrCodeTests.secret)&issuer=Portal"
  /// The same link with every optional parameter set, so a larger QR version is selected.
  private static let longLink = TotpQrCodeTests.link
    + "&digits=6&period=30&algorithm=SHA1&image=https://example.com/icon.png"
  /// The link as the backend delivers it when it percent-encodes the whole value.
  private static let encodedWholeLink = "otpauth%3A%2F%2Ftotp%2FPortal%3Fsecret%3D\(TotpQrCodeTests.secret)"
  /// What `encodedWholeLink` decodes to, and therefore what its QR must encode.
  private static let decodedWholeLink = "otpauth://totp/Portal?secret=\(TotpQrCodeTests.secret)"

  private var logger = RecordingLogger()

  /// The TOTP-required result a first-time enrollment produces, around `link`.
  private func result(link: String?) -> TotpRequiredResult {
    TotpRequiredResult(userJwt: "jwt", totpLink: link, endUserId: "user-1")
  }

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

  // MARK: - totpSecret

  func test_totpSecret_willReadSecret_whenFirstParameter() {
    let subject = self.result(link: "otpauth://totp/Portal?secret=\(Self.secret)&issuer=Portal")

    XCTAssertEqual(subject.totpSecret, Self.secret)
  }

  func test_totpSecret_willReadSecret_whenNotFirstParameter() {
    let subject = self.result(link: "otpauth://totp/Portal?issuer=Portal&digits=6&secret=\(Self.secret)")

    XCTAssertEqual(subject.totpSecret, Self.secret)
  }

  func test_totpSecret_willReadSecret_whenLabelAndIssuerPercentEncoded() {
    let subject = self.result(
      link: "otpauth://totp/Portal%20Inc%3Auser%40example.com?issuer=Portal%20Inc&secret=\(Self.secret)"
    )

    XCTAssertEqual(subject.totpSecret, Self.secret)
  }

  func test_totpSecret_willReadSecret_whenWholeLinkPercentEncoded() {
    let subject = self.result(link: Self.encodedWholeLink)

    XCTAssertEqual(subject.totpSecret, Self.secret)
  }

  func test_totpSecret_willUppercaseLowercaseSecret() {
    let subject = self.result(link: "otpauth://totp/Portal?secret=\(Self.secret.lowercased())&issuer=Portal")

    XCTAssertEqual(subject.totpSecret, Self.secret, "An authenticator app expects the upper-case base32 alphabet")
  }

  func test_totpSecret_willAcceptUppercaseScheme() {
    let subject = self.result(link: "OTPAUTH://totp/Portal?secret=\(Self.secret)")

    XCTAssertEqual(subject.totpSecret, Self.secret)
  }

  func test_totpSecret_willAcceptPaddedSecret() {
    let subject = self.result(link: "otpauth://totp/Portal?secret=\(Self.secret)====")

    XCTAssertNotNil(subject.totpSecret)
    XCTAssertEqual(subject.totpSecret, Self.secret + "====", "Trailing base32 padding is part of the value, not a rejection reason")
  }

  func test_totpSecret_willTrimWhitespaceAroundLink() {
    let subject = self.result(link: "  \(Self.link)  \n")

    XCTAssertEqual(subject.totpSecret, Self.secret)
  }

  func test_totpSecret_willIgnoreFragment() {
    let subject = self.result(link: Self.link + "#frag")

    XCTAssertEqual(subject.totpSecret, Self.secret)
  }

  func test_totpSecret_willReturnNil_whenTotpLinkNil() {
    let subject = self.result(link: nil)

    XCTAssertNil(subject.totpSecret, "The already-enrolled shape carries no link to read")
  }

  func test_totpSecret_willReturnNil_whenTotpLinkEmpty() {
    XCTAssertNil(self.result(link: "").totpSecret)
  }

  func test_totpSecret_willReturnNil_whenTotpLinkBlank() {
    XCTAssertNil(self.result(link: "   ").totpSecret)
  }

  func test_totpSecret_willReturnNil_whenNoSecretParameter() {
    XCTAssertNil(self.result(link: "otpauth://totp/Portal:user@example.com?issuer=Portal").totpSecret)
  }

  func test_totpSecret_willReturnNil_whenSecretEmpty() {
    XCTAssertNil(self.result(link: "otpauth://totp/Portal?secret=&issuer=Portal").totpSecret)
  }

  func test_totpSecret_willReturnNil_whenSecretNotBase32() {
    XCTAssertNil(self.result(link: "otpauth://totp/Portal?secret=not-base32!!").totpSecret)
  }

  func test_totpSecret_willReturnNil_whenSchemeNotOtpauth() {
    XCTAssertNil(
      self.result(link: "https://example.com?secret=\(Self.secret)").totpSecret,
      "A non-otpauth link is never treated as an enrollment URI, whatever it carries"
    )
  }

  func test_totpSecret_willReturnNil_whenBareSecret() {
    XCTAssertNil(
      self.result(link: Self.secret).totpSecret,
      "The SDK reads the link's query only; a bare secret stays an example-app affordance"
    )
  }

  func test_totpSecret_willUseLastOccurrence_whenSecretDuplicated() {
    let subject = self.result(link: "otpauth://totp/Portal?secret=AAAA&secret=\(Self.secret)")

    XCTAssertEqual(subject.totpSecret, Self.secret, "Last occurrence wins, as in the redirect query parser")
  }

  func test_totpSecret_willReturnNilQuickly_whenHostileLength() {
    let separators = "otpauth://totp/x?" + String(repeating: "&", count: 200_000) + "issuer=a"
    let padding = String(repeating: "=", count: 200_000)

    let separatorStart = Date()
    let separatorSecret = self.result(link: separators).totpSecret
    let separatorElapsed = Date().timeIntervalSince(separatorStart)

    let paddingStart = Date()
    let paddingSecret = self.result(link: padding).totpSecret
    let paddingElapsed = Date().timeIntervalSince(paddingStart)

    XCTAssertNil(separatorSecret)
    XCTAssertNil(paddingSecret)
    XCTAssertLessThan(separatorElapsed, 2, "A linear scan must not degrade on a hostile link")
    XCTAssertLessThan(paddingElapsed, 2)
  }

  // MARK: - qrCodeImage

  func test_qrCodeImage_willProduceSquareImageSizedByScale() throws {
    let image = try self.result(link: Self.link).qrCodeImage(scale: 10)
    let cgImage = try XCTUnwrap(image.cgImage)
    let modules = try XCTUnwrap(referenceModuleCount(for: Self.link, correctionLevel: "M"))

    XCTAssertEqual(cgImage.width, cgImage.height)
    XCTAssertEqual(cgImage.width, (modules + 8) * 10, "The symbol plus a four-module quiet zone on each side")
    XCTAssertEqual(cgImage.width % 10, 0, "Every module is a whole number of pixels")
  }

  func test_qrCodeImage_willScaleLinearly() throws {
    let small = try XCTUnwrap(self.result(link: Self.link).qrCodeImage(scale: 4).cgImage)
    let large = try XCTUnwrap(self.result(link: Self.link).qrCodeImage(scale: 8).cgImage)

    XCTAssertEqual(large.width, 2 * small.width)
    XCTAssertEqual(large.height, 2 * small.height)
  }

  func test_qrCodeImage_willUseDefaultScale10() throws {
    let defaulted = try self.result(link: Self.link).qrCodeImage()
    let explicit = try self.result(link: Self.link).qrCodeImage(scale: 10)

    let defaultedImage = try XCTUnwrap(defaulted.cgImage)
    let explicitImage = try XCTUnwrap(explicit.cgImage)
    XCTAssertEqual(defaultedImage.width, explicitImage.width)
    XCTAssertEqual(defaultedImage.height, explicitImage.height)
    XCTAssertEqual(try XCTUnwrap(defaulted.pngData()), try XCTUnwrap(explicit.pngData()), "The same link always renders the same bytes")
  }

  func test_qrCodeImage_willLeaveQuietZoneWhite() throws {
    let image = try self.result(link: Self.link).qrCodeImage(scale: 10)
    let pixels = try XCTUnwrap(PixelBuffer(image))

    XCTAssertEqual(pixels.pixel(0, 0), .white)
    XCTAssertEqual(pixels.pixel(pixels.width - 1, 0), .white)
    XCTAssertEqual(pixels.pixel(0, pixels.height - 1), .white)
    XCTAssertEqual(pixels.pixel(pixels.width - 1, pixels.height - 1), .white)
    XCTAssertEqual(pixels.pixel(39, 39), .white, "The last pixel of the four-module quiet zone at scale 10")
  }

  func test_qrCodeImage_willContainBlackModules() throws {
    let image = try self.result(link: Self.link).qrCodeImage(scale: 10)
    let pixels = try XCTUnwrap(PixelBuffer(image))

    XCTAssertEqual(pixels.pixel(45, 45), .black, "The centre of module (4, 4): the outer ring of a finder pattern")

    let low = Int(Double(pixels.width) * 0.4)
    let high = Int(Double(pixels.width) * 0.6)
    var centralDarkPixels = 0
    for y in low ..< high {
      for x in low ..< high where pixels.pixel(x, y).isDark {
        centralDarkPixels += 1
      }
    }
    XCTAssertGreaterThan(centralDarkPixels, 0, "The middle of the symbol carries data, not blank space")
  }

  func test_qrCodeImage_willBePureBlackAndWhiteOpaque() throws {
    let image = try self.result(link: Self.link).qrCodeImage(scale: 2)
    let pixels = try XCTUnwrap(PixelBuffer(image))

    var offending: (x: Int, y: Int, pixel: SampledPixel)?
    for y in 0 ..< pixels.height {
      for x in 0 ..< pixels.width {
        let pixel = pixels.pixel(x, y)
        if pixel != .black, pixel != .white {
          offending = (x, y, pixel)
          break
        }
      }
      if offending != nil {
        break
      }
    }

    XCTAssertNil(
      offending.map { "(\($0.x), \($0.y)) = \($0.pixel)" },
      "Every pixel is opaque pure black or opaque pure white — no anti-aliasing, no transparency"
    )
  }

  func test_qrCodeImage_willRoundTripThroughCIDetector() throws {
    let image = try self.result(link: Self.link).qrCodeImage(scale: 10)

    XCTAssertEqual(decodeQr(image), Self.link, "A real decoder reads the enrollment link back byte for byte")
  }

  func test_qrCodeImage_willRoundTripLongLink() throws {
    let image = try self.result(link: Self.longLink).qrCodeImage(scale: 10)

    XCTAssertEqual(decodeQr(image), Self.longLink, "A larger QR version is selected automatically")
  }

  func test_qrCodeImage_willEncodeDecodedPayload_whenLinkPercentEncodedWhole() throws {
    let image = try self.result(link: Self.encodedWholeLink).qrCodeImage(scale: 10)

    XCTAssertEqual(decodeQr(image), Self.decodedWholeLink, "An authenticator app must scan the decoded URI, not the encoded string")
  }

  func test_qrCodeImage_willEncodeTrimmedPayload() throws {
    let image = try self.result(link: "  \(Self.link)  ").qrCodeImage(scale: 10)

    XCTAssertEqual(decodeQr(image), Self.link)
  }

  func test_qrCodeImage_willUseErrorCorrectionM() throws {
    let image = try self.result(link: Self.link).qrCodeImage(scale: 10)
    let cgImage = try XCTUnwrap(image.cgImage)
    let producedModules = cgImage.width / 10 - 8

    let mediumModules = try XCTUnwrap(referenceModuleCount(for: Self.link, correctionLevel: "M"))
    let lowModules = try XCTUnwrap(referenceModuleCount(for: Self.link, correctionLevel: "L"))

    XCTAssertNotEqual(mediumModules, lowModules, "The payload was chosen so the two levels pick different versions")
    XCTAssertEqual(producedModules, mediumModules, "Enrollment QRs are rendered at error-correction level M")
    XCTAssertNotEqual(producedModules, lowModules)
  }

  func test_qrCodeImage_willThrowTotpQrUnavailable_whenTotpLinkNil() {
    XCTAssertThrowsError(try self.result(link: nil).qrCodeImage()) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_qrCodeImage_willThrowTotpQrUnavailable_whenTotpLinkEmpty() {
    XCTAssertThrowsError(try self.result(link: "").qrCodeImage()) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_qrCodeImage_willThrowTotpQrUnavailable_whenTotpLinkBlank() {
    XCTAssertThrowsError(try self.result(link: "   ").qrCodeImage()) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_qrCodeImage_willThrowTotpQrUnavailable_whenNotOtpauth() {
    XCTAssertThrowsError(try self.result(link: "https://example.com?secret=\(Self.secret)").qrCodeImage()) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_qrCodeImage_willThrowTotpQrUnavailable_whenNoSecret() {
    XCTAssertThrowsError(try self.result(link: "otpauth://totp/Portal?issuer=Portal").qrCodeImage()) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_qrCodeImage_willThrowTotpQrUnavailable_whenSecretNotBase32() {
    XCTAssertThrowsError(try self.result(link: "otpauth://totp/Portal?secret=not-base32!!").qrCodeImage()) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_qrCodeImage_willThrowTotpQrUnavailable_whenScaleNotPositive() {
    let subject = self.result(link: Self.link)

    XCTAssertThrowsError(try subject.qrCodeImage(scale: 0)) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable, "A zero scale must fail, never produce a zero-size bitmap")
    }
    XCTAssertThrowsError(try subject.qrCodeImage(scale: -1)) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_qrCodeImage_willNotLogLinkOrSecret() throws {
    _ = try self.result(link: Self.link).qrCodeImage(scale: 4)

    let failures: [(link: String?, scale: CGFloat)] = [
      (nil, 10),
      ("", 10),
      ("   ", 10),
      ("https://example.com?secret=\(Self.secret)", 10),
      ("otpauth://totp/Portal?issuer=Portal", 10),
      ("otpauth://totp/Portal?secret=not-base32!!", 10),
      (Self.link, 0)
    ]
    for failure in failures {
      XCTAssertThrowsError(try self.result(link: failure.link).qrCodeImage(scale: failure.scale))
    }

    self.logger.assertNoSecret(Self.secret)
    XCTAssertFalse(self.logger.contains("otpauth"), "Neither the link nor its scheme reaches a log on any path")
    XCTAssertFalse(self.logger.contains("user@example.com"), "The link's account label is an email address")
    XCTAssertTrue(
      self.logger.messages.filter { $0.contains("Totp") || $0.contains("QR") || $0.contains("qr") }.isEmpty,
      "The QR paths log nothing at all, on success or on any failure"
    )
  }

  func test_qrCodeImage_willNotIncludeLinkInErrorDescription() {
    XCTAssertThrowsError(try self.result(link: "https://example.com?secret=\(Self.secret)").qrCodeImage()) { error in
      let description = (error as? LocalizedError)?.errorDescription ?? "\(error)"
      XCTAssertFalse(description.contains(Self.secret), "The failure names the problem, never the link that carried the secret")
      XCTAssertFalse(error.localizedDescription.contains(Self.secret))
    }
  }

  func test_qrCodeImage_willBeSafeFromConcurrentCalls() async throws {
    let link = Self.link

    let decoded = try await withThrowingTaskGroup(of: String?.self) { group -> [String?] in
      for _ in 0 ..< 8 {
        group.addTask {
          let result = TotpRequiredResult(userJwt: "jwt", totpLink: link, endUserId: "user-1")
          let image = try result.qrCodeImage(scale: 6)
          return decodeQr(image)
        }
      }

      var results: [String?] = []
      for try await value in group {
        results.append(value)
      }
      return results
    }

    XCTAssertEqual(decoded.count, 8)
    for value in decoded {
      XCTAssertEqual(value, link, "The shared CIContext is safe to render from concurrently")
    }
  }

  // MARK: - portalTotpQrCodeImage

  func test_portalTotpQrCodeImage_willMatchExtensionOutput() throws {
    let free = try portalTotpQrCodeImage(otpAuthUrl: Self.link, scale: 10)
    let fromResult = try self.result(link: Self.link).qrCodeImage(scale: 10)

    let freeImage = try XCTUnwrap(free.cgImage)
    let resultImage = try XCTUnwrap(fromResult.cgImage)
    XCTAssertEqual(freeImage.width, resultImage.width)
    XCTAssertEqual(freeImage.height, resultImage.height)
    XCTAssertEqual(try XCTUnwrap(free.pngData()), try XCTUnwrap(fromResult.pngData()), "Hosts holding the link get the identical image")
  }

  func test_portalTotpQrCodeImage_willRoundTrip() throws {
    let image = try portalTotpQrCodeImage(otpAuthUrl: Self.link)

    XCTAssertEqual(decodeQr(image), Self.link)
  }

  func test_portalTotpQrCodeImage_willThrow_whenEmpty() {
    XCTAssertThrowsError(try portalTotpQrCodeImage(otpAuthUrl: "")) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_portalTotpQrCodeImage_willThrow_whenNotOtpauth() {
    XCTAssertThrowsError(try portalTotpQrCodeImage(otpAuthUrl: "https://x?secret=\(Self.secret)")) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_portalTotpQrCodeImage_willThrow_whenNoSecret() {
    XCTAssertThrowsError(try portalTotpQrCodeImage(otpAuthUrl: "otpauth://totp/Portal")) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  func test_portalTotpQrCodeImage_willAcceptUppercaseSchemeAndTrim() throws {
    let payload = "OTPAUTH://totp/Portal?secret=\(Self.secret)"
    let image = try portalTotpQrCodeImage(otpAuthUrl: "  \(payload) ")

    XCTAssertEqual(decodeQr(image), payload, "The trimmed link is encoded verbatim, case included")
  }

  func test_portalTotpQrCodeImage_willThrow_whenScaleNotPositive() {
    XCTAssertThrowsError(try portalTotpQrCodeImage(otpAuthUrl: Self.link, scale: 0)) { error in
      XCTAssertEqual(error as? PortalAuthError, .totpQrUnavailable)
    }
  }

  // MARK: - TotpRequiredResult

  func test_totpRequiredResult_willBeEquatable() {
    let first = self.result(link: Self.link)
    let second = self.result(link: Self.link)
    let enrolled = self.result(link: nil)

    XCTAssertEqual(first, second)
    XCTAssertNotEqual(first, enrolled, "The enrollment link is part of the value")
    XCTAssertNotEqual(first, TotpRequiredResult(userJwt: "other-jwt", totpLink: Self.link, endUserId: "user-1"))
    XCTAssertNotEqual(first, TotpRequiredResult(userJwt: "jwt", totpLink: Self.link, endUserId: "user-2"))
  }
}

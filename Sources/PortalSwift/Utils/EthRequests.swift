import Foundation

class EthRequestUtils {
  func hexStringToByteArray(hexString: String) -> [UInt8] {
    // Verify the length of the string
    if hexString.count % 2 != 0 {
      fatalError("[Portal] hexStringToByteArray() detected invalid input length for hexString.")
    }

    // Get the total bytes
    let totalBytes = hexString.count / 2

    // Initialize a [UInt8] array with a length matching totalBytes
    var byteArray = [UInt8](repeating: 0, count: totalBytes)

    // Loop over the resulting array
    for i in 0 ..< totalBytes {
      // Get the byte at the current index
      let start = hexString.index(hexString.startIndex, offsetBy: i * 2)
      let end = hexString.index(start, offsetBy: 2)
      let substring = hexString[start ..< end].lowercased()

      // Get the integer matching the current byte and assign it to the array
      if let byte = UInt8(substring, radix: 16) {
        byteArray[i] = byte
      } else {
        fatalError("[Portal] hexStringToByteArray() failed to convert byte at index \(i).")
      }
    }

    // Return a byte array
    return byteArray
  }

  func hexStringToNumber(hexBalance: String) -> Double {
    guard let balanceNumber = Double(hexBalance) else {
      fatalError("Invalid hexBalance")
    }

    let balance = (balanceNumber / 1e18) * 100_000

    return (balance * 100_000).rounded(.toNearestOrAwayFromZero) / 100_000
  }

  func hexStringToString(hexInput: String) -> String {
    // Get the proper hex string
    let byteArray = self.hexStringToByteArray(hexString: hexInput.replacingOccurrences(of: "0x", with: ""))

    // Create an array of characters
    let stringArray = byteArray.map { charCode -> String in
      String(Character(UnicodeScalar(Int(charCode))!))
    }

    // Join the array of characters
    let string = stringArray.joined()

    // Return the final string
    return string
  }

  func numberToHexString(value: Double) -> String {
    let longBits = value.bitPattern
    let hexString = String(longBits, radix: 16)

    return "0x" + hexString
  }
}

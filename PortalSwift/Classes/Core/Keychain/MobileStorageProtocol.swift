//
//  MobileStorageProtocol.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/10/23.
//
import Foundation

public protocol MobileStorageProtocol {
  func getAddress() throws -> String
  func getSigningShare() throws -> String
  func setAddress(address: String, completion: @escaping (Result<OSStatus>) -> Void)
  func setSigningShare(signingShare: String, completion: @escaping (Result<OSStatus>) -> Void)
  func deleteAddress() throws
  func deleteSigningShare() throws
  func validateOperations(completion: @escaping (Result<OSStatus>) -> Void)
}

//
//  MockGDriveStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import UIKit

public class MockGDriveStorage: GDriveStorage {
  override public init(clientID: String, viewController: UIViewController) {
    super.init(clientID: clientID, viewController: viewController)
  }

  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(data: true))
  }

  override public func read(completion: @escaping (Result<String>) -> Void) {
    completion(Result(data: mockBackupShare))
  }

  override public func write(privateKey _: String, completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(data: true))
  }

  override public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    callback(Result(data: true))
  }
}

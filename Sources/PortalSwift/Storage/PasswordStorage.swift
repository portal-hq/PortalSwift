//
//  PasswordStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public enum PasswordStorageError: Error {
  case passwordMissing(String)
}

/// Responsible for CRUD actions for items in the specified storage.
public class PasswordStorage: Storage {
  override public init() {}
}

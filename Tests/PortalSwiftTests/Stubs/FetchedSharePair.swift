//
//  FetchedSharePair.swift
//
//
//  Created by Ahmed Ragab on 04/09/2024.
//

import Foundation
@testable import PortalSwift

extension FetchedSharePair {
  static func stub(
    id: String = "sample-id",
    createdAt: String = "2024-08-24T12:00:00Z",
    status: PortalSharePairStatus = .completed
  ) -> FetchedSharePair {
    return FetchedSharePair(
      id: id,
      createdAt: createdAt,
      status: status
    )
  }
}

extension PortalSharePairStatus {
  static func stub() -> PortalSharePairStatus {
    return .completed
  }
}

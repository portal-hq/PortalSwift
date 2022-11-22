//
//  MockPortalApi.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalApi: PortalApi {
  public var client: Client?
  public var dapps: [Dapp]?
  public var networks: [ContractNetwork]?

  public override func getClient(completion: @escaping (Result<Any>) -> Void) -> Void {
    // Make an instance of Client.
    let client = Client(
      id: "fakeClientID",
      address: "address",
      clientApiKey: "clientApiKey",
      custodian: Custodian(
        id: "fakeCustodianID",
        name: "name"
      )
    )

    // Call the completion handler.
    completion(Result(data: client))
  }

  public override func getEnabledDapps(completion: @escaping (Result<Any>) -> Void) -> Void {
    if let dapps = dapps {
      completion(Result(data: dapps))
    }
  }

  public override func getSupportedNetworks(completion: @escaping (Result<Any>) -> Void) -> Void {
    if let networks = networks {
      completion(Result(data: networks))
    }
  }
}

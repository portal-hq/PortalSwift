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

  public override func getClient(completion: @escaping (Client) -> Void) throws -> Void {
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
    completion(client)
  }

  public override func getEnabledDapps(completion: @escaping ([Dapp]) -> Void) throws -> Void {
    if let dapps = dapps {
      completion(dapps)
    }
  }

  public override func getSupportedNetworks(completion: @escaping ([ContractNetwork]) -> Void) throws -> Void {
    if let networks = networks {
      completion(networks)
    }
  }
}

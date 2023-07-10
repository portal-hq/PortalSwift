//
//  MockPortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalApi: PortalApi {
    public var client: Client?
    public var dapps: [Dapp]?
    public var networks: [ContractNetwork]?

    override public func getClient(completion: @escaping (Result<Client>) -> Void) {
        // Make an instance of Client.
        let client = Client(
            id: "fakeClientID",
            address: mockAddress,
            clientApiKey: "clientApiKey",
            custodian: Custodian(
                id: "fakeCustodianID",
                name: "name"
            )
        )

        // Call the completion handler.
        completion(Result(data: client))
    }

    override public func getEnabledDapps(completion: @escaping (Result<[Dapp]>) -> Void) {
        if let dapps = dapps {
            completion(Result(data: dapps))
        }
    }

    override public func getSupportedNetworks(completion: @escaping (Result<[ContractNetwork]>) -> Void) {
        if let networks = networks {
            completion(Result(data: networks))
        }
    }
}

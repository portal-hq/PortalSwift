//
//  PortalKeyChainAccessMock.swift
//
//
//  Created by Ahmed Ragab on 27/08/2024.
//

import Foundation
@testable import PortalSwift

class PortalKeyChainAccessMock: PortalKeychainAccessProtocol {
    func addItem(_ key: String, value: String) throws { }

    func deleteItem(_ key: String) throws { }
    
    var getItemReturnValue: String = ""
    func getItem(_ key: String) throws -> String {
        return getItemReturnValue
    }
    
    func updateItem(_ key: String, value: String) throws { }
}

//
//  PortalRepository.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//
import Foundation
import PortalSwift

protocol PortalRepositoryProtocol {
  @discardableResult
  func post<ResponseType>(_ path: String, withBearerToken: String?, andPayload: Codable?, mappingInResponse response: ResponseType.Type) async throws -> ResponseType where ResponseType: Decodable
}

struct PortalRepository: PortalRepositoryProtocol {
  private let portalRequests = PortalRequests()
  func post<ResponseType>(_ path: String, withBearerToken: String? = nil, andPayload: (any Codable)? = nil, mappingInResponse _: ResponseType.Type) async throws -> ResponseType where ResponseType: Decodable {
    guard let url = URL(string: "\(AppSettings.Config.custodianServerUrl)\(path)") else {
      throw URLError(.badURL)
    }
    let responseData = try await portalRequests.post(url, withBearerToken: withBearerToken, andPayload: andPayload)
    let response = try JSONDecoder().decode(ResponseType.self, from: responseData)
    return response
  }
}

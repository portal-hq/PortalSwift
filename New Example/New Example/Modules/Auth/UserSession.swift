//
//  UserSession.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//
import Foundation

struct UserData: Codable {
  var clientApiKey: String
  var clientId: String
  var exchangeUserId: Int
  var username: String
}

class UserSession {
  static let shared = UserSession()

  var user: UserData?

  private init() {}
}

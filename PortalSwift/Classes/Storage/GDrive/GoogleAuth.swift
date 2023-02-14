//
//  GoogleAuth.swift
//  PortalSwift
//
//  Created by Blake Williams on 2/7/23.
//

import Foundation
import GoogleSignIn

public enum GoogleAuthError: Error {
  case noUserFound
  case unableToReadAccessToken
}

class GoogleAuth {
  public var auth: GIDSignIn
  public var config: GIDConfiguration
  private var view: UIViewController
  
  init(config: GIDConfiguration, view: UIViewController) {
    auth = GIDSignIn.sharedInstance
    self.config = config
    self.view = view
  }
  
  func getAccessToken(callback: @escaping (Result<String>) -> Void) {
    if auth.currentUser == nil {
      signIn() { (user) in
        if user.error != nil {
          callback(Result(error: user.error!))
        } else if user.data == nil {
          callback(Result(error: GoogleAuthError.noUserFound))
        }
        
        callback(Result(data: user.data!.authentication.accessToken))
      }
    }
  }

  func getCurrentUser() -> GIDGoogleUser? {
    return auth.currentUser
  }
  
  func signIn(callback: @escaping (Result<GIDGoogleUser>) -> Void) {
    auth.signIn(with: config, presenting: view) {
      (user, error) in
      if error != nil {
        callback(Result(error: error! as Error))
      } else {
        callback(Result(data: user!))
      }
    }
  }
  
  func signOut() {
    auth.signOut()
  }
}

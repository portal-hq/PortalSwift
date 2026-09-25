//
//  AppDelegate.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import FirebaseCore
import PortalSwift
import Pulse
import PulseProxy
import UIKit

protocol PortalExampleAppDelegate {
  var connect: PortalConnect? { get set }
  var connect2: PortalConnect? { get set }
  var portal: PortalProtocol? { get set }
}

public enum PortalExampleAppError: Error {
  case addressNotFound(_: String = "Address not found")
  case alchemyKeyNotFound(_: String = "Alchemy API key not found")
  /// The `BACKUP_WITH_PORTAL` build flag disagrees with the auth environment's runtime
  /// `backupWithPortalEnabled`. Carries the whole actionable sentence, because the fix is a
  /// rebuild and the reader needs both values to know which way round.
  case backupConfigMismatch(_ message: String)
  case cantLoadInfoPlist(_: String = "Can't load info.plist")
  case clientAuthNotConfigured(_: String = "Client Auth is not configured")
  case clientInformationUnavailable(_: String = "Client information unavailable")
  case configurationNotSet(_: String = "Configuration not set")
  case couldNotParseCustodianResponse(_: String = "Could not parse custodian response")
  case custodianServerUrlNotSet(_: String = "Custodian server URL not set")
  case ejectUnavailableForSession(_: String = "Eject is unavailable for a Client Auth session")
  case environmentNotSet(_: String = "Environment not set")
  case invalidResponseTypeForRequest(_: String = "Invalid response type for request")
  case portalNotInitialized(_: String = "Portal not initialized")
  case unexpectedTypeForResult(PortalProviderResult)
  case userNotLoggedIn(_: String = "User not logged in")
}

extension PortalExampleAppError: LocalizedError {
  /// Surfaces the message each case already carries.
  ///
  /// Without this, `localizedDescription` is Foundation's "The operation couldn't be completed"
  /// boilerplate, and every one of these errors is written to the on-screen log or reported
  /// through `ClientAuthReporter` by description alone.
  public var errorDescription: String? {
    switch self {
    case let .addressNotFound(message),
         let .alchemyKeyNotFound(message),
         let .backupConfigMismatch(message),
         let .cantLoadInfoPlist(message),
         let .clientAuthNotConfigured(message),
         let .clientInformationUnavailable(message),
         let .configurationNotSet(message),
         let .couldNotParseCustodianResponse(message),
         let .custodianServerUrlNotSet(message),
         let .ejectUnavailableForSession(message),
         let .environmentNotSet(message),
         let .invalidResponseTypeForRequest(message),
         let .portalNotInitialized(message),
         let .userNotLoggedIn(message):
      return message
    case let .unexpectedTypeForResult(result):
      return "Unexpected type for result: \(type(of: result.result))"
    }
  }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PortalExampleAppDelegate {
  // NOTE: window ownership lives on `SceneDelegate`; this app runs on the UIScene lifecycle.
  var connect: PortalConnect?
  var connect2: PortalConnect?
  var portal: PortalProtocol?

  func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    URLSessionProxyDelegate.enableAutomaticRegistration()
    NetworkLogger.enableProxy()
    LoggerStore.shared.storeMessage(label: "app", level: .info, message: "Pulse initialized - network proxy enabled")

    // On the UIScene lifecycle this key is never populated — the launch URL arrives in
    // `SceneDelegate.scene(_:willConnectTo:options:)` instead (measured on iOS 26.5). Kept
    // anyway so the app still routes the redirect if it is ever run on the app-delegate
    // lifecycle; the coordinator's read-and-clear stash absorbs a duplicate delivery.
    if let launchURL = launchOptions?[.url] as? URL {
      ClientAuthCoordinator.shared.handleIfClientAuth(launchURL)
    }

    return true
  }

  /// Legacy (app-delegate lifecycle) URL entry point.
  ///
  /// - Returns: `true` only when the Client Auth flow claimed the URL, so other schemes the app
  ///   registers — the Google reversed client id — still reach their own handlers.
  func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    ClientAuthCoordinator.shared.handleIfClientAuth(url)
  }

  func applicationWillResignActive(_: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(_: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    print("application entered background...")
  }

  func applicationWillEnterForeground(_: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    print("Application is now active...")
    if
      self.connect != nil
    {
      print("reconnecting connect 1...")
      let uri = self.connect?.uri ?? nil
      if uri != nil {
        self.connect?.connect(uri! as String)
      }
    }

    if
      self.connect2 != nil
    {
      print("reconnecting connect 2...")
      let uri = self.connect2?.uri ?? nil
      if uri != nil {
        self.connect2?.connect(uri! as String)
      }
    }
  }

  func applicationWillTerminate(_: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
}

//
//  FirebaseAuthViewController.swift
//  SPM Example
//
//  Created for Firebase BYO Auth E2E testing.
//

import FirebaseAuth
import os.log
import PortalSwift
import UIKit

@available(iOS 16.0, *)
protocol FirebaseAuthDelegate: AnyObject {
  func firebaseAuthDidComplete(backup: Bool)
}

@available(iOS 16.0, *)
class FirebaseAuthViewController: UIViewController {

  weak var delegate: FirebaseAuthDelegate?
  var portal: PortalProtocol?
  var user: UserResult?

  private let logger = Logger()
  private let requests = PortalRequests()

  private var isFirebaseSignedIn: Bool {
    Auth.auth().currentUser != nil
  }

  // UI
  private let scrollView = UIScrollView()
  private let stack = UIStackView()
  private let emailField = UITextField()
  private let passwordField = UITextField()
  private let signInButton = UIButton(type: .system)
  private let signUpButton = UIButton(type: .system)
  private let signOutButton = UIButton(type: .system)
  private let statusLabel = UILabel()
  private let backupButton = UIButton(type: .system)
  private let recoverButton = UIButton(type: .system)
  private let ejectButton = UIButton(type: .system)
  private let resultLabel = UILabel()
  private let activityIndicator = UIActivityIndicatorView(style: .large)
  private let overlayView = UIView()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = "Firebase BYO Auth"

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(dismissSelf)
    )

    setupUI()
    updateUI()
  }

  // MARK: - UI Setup

  private func setupUI() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
      stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor, constant: -20),
    ])

    // Section: Firebase Sign In
    let authHeader = makeSectionHeader("Firebase Authentication")
    stack.addArrangedSubview(authHeader)

    emailField.placeholder = "Email"
    emailField.borderStyle = .roundedRect
    emailField.autocapitalizationType = .none
    emailField.keyboardType = .emailAddress
    emailField.returnKeyType = .next
    stack.addArrangedSubview(emailField)

    passwordField.placeholder = "Password"
    passwordField.borderStyle = .roundedRect
    passwordField.isSecureTextEntry = true
    passwordField.returnKeyType = .done
    stack.addArrangedSubview(passwordField)

    let authRow = UIStackView()
    authRow.axis = .horizontal
    authRow.spacing = 12
    authRow.distribution = .fillEqually

    signInButton.setTitle("Sign In", for: .normal)
    signInButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
    signInButton.backgroundColor = .systemBlue
    signInButton.setTitleColor(.white, for: .normal)
    signInButton.layer.cornerRadius = 8
    signInButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    signInButton.addTarget(self, action: #selector(handleSignIn), for: .touchUpInside)
    authRow.addArrangedSubview(signInButton)

    signUpButton.setTitle("Sign Up", for: .normal)
    signUpButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
    signUpButton.backgroundColor = .systemGreen
    signUpButton.setTitleColor(.white, for: .normal)
    signUpButton.layer.cornerRadius = 8
    signUpButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    signUpButton.addTarget(self, action: #selector(handleSignUp), for: .touchUpInside)
    authRow.addArrangedSubview(signUpButton)

    stack.addArrangedSubview(authRow)

    signOutButton.setTitle("Sign Out", for: .normal)
    signOutButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
    signOutButton.backgroundColor = .systemRed
    signOutButton.setTitleColor(.white, for: .normal)
    signOutButton.layer.cornerRadius = 8
    signOutButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    signOutButton.addTarget(self, action: #selector(handleSignOut), for: .touchUpInside)
    stack.addArrangedSubview(signOutButton)

    statusLabel.text = "Not signed in"
    statusLabel.textAlignment = .center
    statusLabel.font = .systemFont(ofSize: 14)
    statusLabel.textColor = .secondaryLabel
    stack.addArrangedSubview(statusLabel)

    stack.addArrangedSubview(makeSeparator())

    // Section: Backup & Recover
    let backupHeader = makeSectionHeader("Firebase Backup & Recover")
    stack.addArrangedSubview(backupHeader)

    backupButton.setTitle("Firebase Backup", for: .normal)
    backupButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
    backupButton.backgroundColor = .systemOrange
    backupButton.setTitleColor(.white, for: .normal)
    backupButton.layer.cornerRadius = 8
    backupButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    backupButton.addTarget(self, action: #selector(handleBackup), for: .touchUpInside)
    stack.addArrangedSubview(backupButton)

    recoverButton.setTitle("Firebase Recover", for: .normal)
    recoverButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
    recoverButton.backgroundColor = .systemPurple
    recoverButton.setTitleColor(.white, for: .normal)
    recoverButton.layer.cornerRadius = 8
    recoverButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    recoverButton.addTarget(self, action: #selector(handleRecover), for: .touchUpInside)
    stack.addArrangedSubview(recoverButton)

    // Eject button
    ejectButton.setTitle("Firebase Eject", for: .normal)
    ejectButton.backgroundColor = .systemRed
    ejectButton.setTitleColor(.white, for: .normal)
    ejectButton.layer.cornerRadius = 8
    ejectButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
    ejectButton.addTarget(self, action: #selector(handleEject), for: .touchUpInside)
    ejectButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    stack.addArrangedSubview(ejectButton)

    stack.addArrangedSubview(makeSeparator())

    // Result label
    resultLabel.text = ""
    resultLabel.textAlignment = .center
    resultLabel.font = .systemFont(ofSize: 13)
    resultLabel.numberOfLines = 0
    stack.addArrangedSubview(resultLabel)

    // Loading overlay
    overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
    overlayView.isHidden = true
    overlayView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(overlayView)
    NSLayoutConstraint.activate([
      overlayView.topAnchor.constraint(equalTo: view.topAnchor),
      overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    activityIndicator.hidesWhenStopped = true
    activityIndicator.color = .systemBlue
    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(activityIndicator)
    NSLayoutConstraint.activate([
      activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }

  // MARK: - UI State

  private func updateUI() {
    let signedIn = isFirebaseSignedIn
    if let email = Auth.auth().currentUser?.email {
      statusLabel.text = "Signed in: \(email)"
      statusLabel.textColor = .systemGreen
    } else {
      statusLabel.text = "Not signed in"
      statusLabel.textColor = .secondaryLabel
    }

    signInButton.isEnabled = !signedIn
    signInButton.alpha = signedIn ? 0.5 : 1.0
    signUpButton.isEnabled = !signedIn
    signUpButton.alpha = signedIn ? 0.5 : 1.0
    signOutButton.isHidden = !signedIn
    emailField.isEnabled = !signedIn
    passwordField.isEnabled = !signedIn

    Task {
      let walletExists = try await portal?.doesWalletExist(nil) ?? false
      let isOnDevice = (try? await portal?.isWalletOnDevice(nil)) ?? false
      let recoveryMethods = try await portal?.availableRecoveryMethods(nil) ?? []

      DispatchQueue.main.async {
        self.backupButton.isEnabled = signedIn && walletExists && isOnDevice
        self.backupButton.alpha = self.backupButton.isEnabled ? 1.0 : 0.5
        self.recoverButton.isEnabled = signedIn && recoveryMethods.contains(.Firebase)
        self.recoverButton.alpha = self.recoverButton.isEnabled ? 1.0 : 0.5
        self.ejectButton.isEnabled = signedIn && recoveryMethods.contains(.Firebase)
        self.ejectButton.alpha = self.ejectButton.isEnabled ? 1.0 : 0.5
      }
    }
  }

  // MARK: - Actions

  @objc private func dismissSelf() {
    dismiss(animated: true)
  }

  @objc private func handleSignIn() {
    guard let email = emailField.text, !email.isEmpty,
          let password = passwordField.text, !password.isEmpty
    else {
      showResult("Enter email and password", success: false)
      return
    }

    startLoading()
    Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
      guard let self else { return }
      self.stopLoading()
      if let error {
        self.logger.error("FirebaseAuth.signIn - ❌ \(error)")
        self.showResult("Sign-in failed: \(error.localizedDescription)", success: false)
        return
      }
      self.logger.debug("FirebaseAuth.signIn - ✅ \(result?.user.email ?? "")")
      self.showResult("Signed in as \(result?.user.email ?? "")", success: true)
      self.updateUI()
    }
  }

  @objc private func handleSignUp() {
    guard let email = emailField.text, !email.isEmpty,
          let password = passwordField.text, !password.isEmpty
    else {
      showResult("Enter email and password", success: false)
      return
    }

    startLoading()
    Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
      guard let self else { return }
      self.stopLoading()
      if let error {
        self.logger.error("FirebaseAuth.signUp - ❌ \(error)")
        self.showResult("Sign-up failed: \(error.localizedDescription)", success: false)
        return
      }
      self.logger.debug("FirebaseAuth.signUp - ✅ \(result?.user.email ?? "")")
      self.showResult("Account created: \(result?.user.email ?? "")", success: true)
      self.updateUI()
    }
  }

  @objc private func handleSignOut() {
    do {
      try Auth.auth().signOut()
      logger.debug("FirebaseAuth.signOut - ✅ Signed out")
      showResult("Signed out", success: true)
      updateUI()
    } catch {
      logger.error("FirebaseAuth.signOut - ❌ \(error)")
      showResult("Sign-out failed: \(error.localizedDescription)", success: false)
    }
  }

  @objc private func handleBackup() {
    Task {
      do {
        guard let portal else {
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        guard isFirebaseSignedIn else {
          showResult("Sign into Firebase first", success: false)
          return
        }
        guard let config = Settings.shared.portalConfig.appConfig else {
          throw PortalExampleAppError.configurationNotSet()
        }
        guard let client = try await portal.client else {
          throw PortalExampleAppError.clientInformationUnavailable()
        }

        startLoading()
        logger.debug("FirebaseAuth.backup - Starting...")

        let (cipherText, storageCallback) = try await portal.backupWallet(.Firebase) { [weak self] status in
          self?.logger.debug("FirebaseAuth.backup - Progress: \(status.status.rawValue), done: \(status.done)")
        }

        let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false

        if !backupWithPortal {
          guard let url = URL(string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/cipher-text") else {
            throw URLError(.badURL)
          }
          let payload = [
            "backupMethod": BackupMethods.Firebase.rawValue,
            "cipherText": cipherText,
          ]

          struct ResponseType: Decodable {
            let message: String?
          }

          let request = PortalAPIRequest(url: url, method: .post, payload: payload)
          _ = try await requests.execute(request: request, mappingInResponse: ResponseType.self)
        }

        try await storageCallback()

        stopLoading()
        showResult("Firebase backup complete!", success: true)
        logger.debug("FirebaseAuth.backup - ✅ Complete")
        delegate?.firebaseAuthDidComplete(backup: true)
        updateUI()
      } catch {
        stopLoading()
        logger.error("FirebaseAuth.backup - ❌ \(error)")
        showResult("Backup failed: \(error)", success: false)
      }
    }
  }

  @objc private func handleRecover() {
    Task {
      do {
        guard let portal else {
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        guard isFirebaseSignedIn else {
          showResult("Sign into Firebase first", success: false)
          return
        }
        guard let config = Settings.shared.portalConfig.appConfig else {
          throw PortalExampleAppError.configurationNotSet()
        }

        startLoading()
        logger.debug("FirebaseAuth.recover - Starting...")

        var cipherText: String? = nil

        guard let client = try await portal.client else {
          throw PortalExampleAppError.clientInformationUnavailable()
        }

        let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false

        if !backupWithPortal {
          guard let url = URL(string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/cipher-text/fetch?backupMethod=FIREBASE") else {
            throw URLError(.badURL)
          }
          let request = PortalAPIRequest(url: url)
          let response = try await requests.execute(request: request, mappingInResponse: CipherTextResult.self)
          cipherText = response.cipherText
        }

        let (ethereum, solana) = try await portal.recoverWallet(.Firebase, withCipherText: cipherText) { [weak self] status in
          self?.logger.debug("FirebaseAuth.recover - Progress: \(status.status.rawValue), done: \(status.done)")
        }

        stopLoading()
        let msg = "Recovered! ETH: \(ethereum)\nSOL: \(solana ?? "N/A")"
        showResult(msg, success: true)
        logger.debug("FirebaseAuth.recover - ✅ ETH: \(ethereum), SOL: \(solana ?? "N/A")")
        delegate?.firebaseAuthDidComplete(backup: false)
        updateUI()
      } catch {
        stopLoading()
        logger.error("FirebaseAuth.recover - ❌ \(error)")
        showResult("Recover failed: \(error)", success: false)
      }
    }
  }

  @objc private func handleEject() {
    Task {
      do {
        guard let portal else {
          throw PortalExampleAppError.portalNotInitialized()
        }
        guard let user else {
          throw PortalExampleAppError.userNotLoggedIn()
        }
        guard isFirebaseSignedIn else {
          showResult("Sign into Firebase first", success: false)
          return
        }
        guard let config = Settings.shared.portalConfig.appConfig else {
          throw PortalExampleAppError.configurationNotSet()
        }
        guard let client = try await portal.client else {
          throw PortalExampleAppError.clientInformationUnavailable()
        }

        startLoading()
        logger.debug("FirebaseAuth.eject - Starting...")

        var cipherText: String? = nil
        var organizationShare: String? = nil
        var organizationSolanaShare: String? = nil

        let backupWithPortal = client.environment?.backupWithPortalEnabled ?? false

        if !backupWithPortal {
          // Self-managed: fetch cipher text and org shares from custodian server
          guard let cipherTextUrl = URL(
            string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/cipher-text/fetch?backupMethod=\(BackupMethods.Firebase.rawValue)"
          ) else {
            throw URLError(.badURL)
          }
          let cipherTextRequest = PortalAPIRequest(url: cipherTextUrl)
          let cipherTextResponse = try await requests.execute(request: cipherTextRequest, mappingInResponse: CipherTextResult.self)
          cipherText = cipherTextResponse.cipherText

          guard let organizationBackupShareUrl = URL(
            string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/org-share/fetch?backupMethod=\(BackupMethods.Firebase.rawValue)-SECP256K1"
          ) else {
            throw URLError(.badURL)
          }
          let organizationBackupShareRequest = PortalAPIRequest(url: organizationBackupShareUrl)
          let organizationBackupShareResponse = try await requests.execute(request: organizationBackupShareRequest, mappingInResponse: OrgShareResult.self)
          organizationShare = organizationBackupShareResponse.orgShare

          // Try to get Solana org share
          guard let organizationSolanaBackupShareUrl = URL(
            string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/org-share/fetch?backupMethod=\(BackupMethods.Firebase.rawValue)-ED25519"
          ) else {
            throw URLError(.badURL)
          }
          let organizationSolanaBackupShareRequest = PortalAPIRequest(url: organizationSolanaBackupShareUrl)
          let organizationSolanaBackupShareResponse = try? await requests.execute(request: organizationSolanaBackupShareRequest, mappingInResponse: OrgShareResult.self)
          if let organizationSolanaBackupShareResponse {
            organizationSolanaShare = organizationSolanaBackupShareResponse.orgShare
          }
        } else {
          // Portal-managed: call prepare-eject for each wallet
          var walletId: String?
          var walletIdEd25519: String? = nil

          for wallet in client.wallets {
            if wallet.curve == .SECP256K1 {
              for backupSharePair in wallet.backupSharePairs {
                if backupSharePair.status == .completed, backupSharePair.backupMethod == .Firebase {
                  walletId = wallet.id
                  break
                }
              }
            } else if wallet.curve == .ED25519 {
              for backupSharePair in wallet.backupSharePairs {
                if backupSharePair.status == .completed, backupSharePair.backupMethod == .Firebase {
                  walletIdEd25519 = wallet.id
                  break
                }
              }
            }
          }

          guard let walletId else {
            throw PortalExampleAppError.clientInformationUnavailable("Could not find Ethereum backup share for backup method.")
          }

          guard let prepareEjectUrl = URL(string: "\(config.custodianServerUrl)/mobile/\(user.exchangeUserId)/prepare-eject") else {
            throw URLError(.badURL)
          }

          let prepareEjectRequest = PortalAPIRequest(url: prepareEjectUrl, method: .post, payload: ["walletId": walletId])
          let prepareEjectResponse = try await requests.execute(request: prepareEjectRequest, mappingInResponse: String.self)
          self.logger.debug("FirebaseAuth.eject - Ethereum wallet ejectable until \(prepareEjectResponse)")

          if let walletIdEd25519 {
            let prepareEjectEd25519Request = PortalAPIRequest(url: prepareEjectUrl, method: .post, payload: ["walletId": walletIdEd25519])
            let prepareEjectResponseEd25519 = try await requests.execute(request: prepareEjectEd25519Request, mappingInResponse: String.self)
            self.logger.debug("FirebaseAuth.eject - Solana wallet ejectable until \(prepareEjectResponseEd25519)")
          }
        }

        let privateKeys = try await portal.ejectPrivateKeys(
          .Firebase,
          withCipherText: cipherText,
          andOrganizationBackupShare: organizationShare,
          andOrganizationSolanaBackupShare: organizationSolanaShare
        )

        stopLoading()

        var resultMessage = "Ejected private keys:\n"
        for (namespace, key) in privateKeys {
          resultMessage += "\(namespace): \(key)\n"
        }
        showResult(resultMessage, success: true)
        logger.debug("FirebaseAuth.eject - ✅ Successfully ejected wallet")
        updateUI()
      } catch {
        stopLoading()
        logger.error("FirebaseAuth.eject - ❌ \(error)")
        showResult("Eject failed: \(error)", success: false)
      }
    }
  }

  // MARK: - Helpers

  private func makeSectionHeader(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = .boldSystemFont(ofSize: 18)
    label.textAlignment = .left
    return label
  }

  private func makeSeparator() -> UIView {
    let sep = UIView()
    sep.backgroundColor = .separator
    sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return sep
  }

  private func showResult(_ message: String, success: Bool) {
    DispatchQueue.main.async {
      self.resultLabel.text = (success ? "✅ " : "❌ ") + message
      self.resultLabel.textColor = success ? .systemGreen : .systemRed
    }
  }

  private func startLoading() {
    DispatchQueue.main.async {
      self.overlayView.isHidden = false
      self.activityIndicator.startAnimating()
      self.view.isUserInteractionEnabled = false
      self.signOutButton.isEnabled = false
      self.navigationItem.leftBarButtonItem?.isEnabled = false
    }
  }

  private func stopLoading() {
    DispatchQueue.main.async {
      self.overlayView.isHidden = true
      self.activityIndicator.stopAnimating()
      self.view.isUserInteractionEnabled = true
      self.signOutButton.isEnabled = true
      self.navigationItem.leftBarButtonItem?.isEnabled = true
    }
  }
}

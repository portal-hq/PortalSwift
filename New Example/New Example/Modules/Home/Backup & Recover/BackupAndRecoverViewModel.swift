//
//  BackupAndRecoverViewModel.swift
//  New Example
//
//  Created by Ahmed Ragab on 24/01/2025.
//

import Foundation

final class BackupAndRecoverViewModel: ObservableObject {
    enum State {
        case none
        case loading
        case backupSuccess(message: String)
        case backupFailed(errorMessage: String)
        case restoreSuccess(message: String)
        case restoreFailed(errorMessage: String)
    }

    @Published private(set) var state: State = .none

    
}

// MARK: - Backup
extension BackupAndRecoverViewModel {
    
}

// MARK: - Recover
extension BackupAndRecoverViewModel {
    
}

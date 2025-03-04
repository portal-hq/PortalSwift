//
//  ThreadSafeDictionary.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 04/03/2025.
//
import Foundation

final class ThreadSafeDictionary<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "io.portalhq.threadSafeDictionary", attributes: .concurrent)

    // Subscript for getting and setting values
    subscript(key: Key) -> Value? {
        get {
            queue.sync { storage[key] }
        }
        set {
            queue.async(flags: .barrier) { self.storage[key] = newValue }
        }
    }

    func remove(_ key: Key) {
        queue.async(flags: .barrier) { self.storage[key] = nil }
    }
}

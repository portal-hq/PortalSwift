//
//  EventBus.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class EventBus {
  private var events: [Events.RawValue: [RegisteredEventHandler]] = [:]
  private var label: String

  public init(label: String) {
    self.label = "\(label)EventBus"
  }

  /// Emits an event from the provider to registered event handlers.
  /// - Parameters:
  ///   - event: The event to be emitted.
  ///   - data: The data to pass to registered event handlers.
  /// - Returns: The Portal Provider instance.
  public func emit(event: Events.RawValue, data: Any) {
    let registeredEventHandlers = self.events[event]

    if registeredEventHandlers == nil {
      print(String(format: "[\(self.label)] Could not find any bindings for event '%@'. Ignoring...", event))
      return
    } else {
      // Invoke all registered handlers for the event
      do {
        for registeredEventHandler in registeredEventHandlers! {
          try registeredEventHandler.handler(data)
        }
      } catch {
        print("[\(self.label)] Error invoking registered handlers", error)
      }

      // Remove once instances
      self.events[event] = registeredEventHandlers?.filter(self.removeOnce)

      return
    }
  }

  /// Registers a callback for an event.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
  public func on(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) -> Void
  ) {
    if self.events[event] == nil {
      self.events[event] = []
    }

    self.events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: false
    ))
  }

  /// Registers a callback for an event. Deletes the registered callback after it's fired once.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
  public func once(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) throws -> Void
  ) {
    if self.events[event] == nil {
      self.events[event] = []
    }

    self.events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: true
    ))
  }

  /// Removes the callback for the specified event.
  /// - Parameters:
  ///   - event: A specific event from the list of Events.
  /// - Returns: An instance of Portal Provider.
  public func removeListener(
    event: Events.RawValue
  ) {
    if self.events[event] == nil {
      print(String(format: "[\(self.label)] Could not find any bindings for event '%@'. Ignoring...", event))
    }

    self.events[event] = nil
  }

  /// Removes the specified event handler.
  /// - Parameters:
  ///   - registeredEventHandler: A specific RegisteredEventHandler.
  /// - Returns: A boolean determining whether the RegisteredEventHandler existed or not.
  private func removeOnce(registeredEventHandler: RegisteredEventHandler) -> Bool {
    return !registeredEventHandler.once
  }

  /// Removes all event handlers.
  public func resetEvents() {
    self.events.forEach { event, _ in
      _ = self.removeListener(event: event)
    }
  }
}

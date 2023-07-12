//
//  EventBus.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class WebSocketEventBus {
  private var events: [ConnectEvents.RawValue: [RegisteredEventHandler]] = [:]
  private var label: String

  public init(label: String) {
    self.label = "\(label)EventBus"
  }

  /// Emits an event from the provider to registered event handlers.
  /// - Parameters:
  ///   - event: The event to be emitted.
  ///   - data: The data to pass to registered event handlers.
  /// - Returns: The Portal Provider instance.
  public func emit(_ event: ConnectEvents, _ data: Any?) {
    let registeredEventHandlers = events[event.rawValue]

    if registeredEventHandlers == nil {
      print(String(format: "[\(label)] Could not find any bindings for event '%@'. Ignoring...", event.rawValue))
      return
    } else {
      // Invoke all registered handlers for the event
      do {
        for registeredEventHandler in registeredEventHandlers! {
          try registeredEventHandler.handler(data)
        }
      } catch {
        print("[\(label)] Error invoking registered handlers", error)
      }

      // Remove once instances
      events[event.rawValue] = registeredEventHandlers?.filter(removeOnce)

      return
    }
  }

  /// Registers a callback for an event.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
  public func on(
    _ event: ConnectEvents,
    _ callback: @escaping (_ data: Any) -> Void
  ) {
    if events[event.rawValue] == nil {
      events[event.rawValue] = []
    }

    events[event.rawValue]?.append(RegisteredEventHandler(
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
    _ event: ConnectEvents,
    _ callback: @escaping (_ data: Any) throws -> Void
  ) {
    if events[event.rawValue] == nil {
      events[event.rawValue] = []
    }

    events[event.rawValue]?.append(RegisteredEventHandler(
      handler: callback,
      once: true
    ))
  }

  /// Removes the callback for the specified event.
  /// - Parameters:
  ///   - event: A specific event from the list of Events.
  /// - Returns: An instance of Portal Provider.
  public func removeListener(
    _ event: ConnectEvents
  ) {
    if events[event.rawValue] == nil {
      print(String(format: "[\(label)] Could not find any bindings for event '%@'. Ignoring...", event.rawValue))
    }

    events[event.rawValue] = nil
  }

  /// Removes the specified event handler.
  /// - Parameters:
  ///   - registeredEventHandler: A specific RegisteredEventHandler.
  /// - Returns: A boolean determining whether the RegisteredEventHandler existed or not.
  private func removeOnce(_ registeredEventHandler: RegisteredEventHandler) -> Bool {
    return !registeredEventHandler.once
  }

  /// Removes all event handlers.
  public func resetEvents() {
    events.forEach { event, _ in
      self.removeListener(ConnectEvents(rawValue: event)!)
    }
  }
}

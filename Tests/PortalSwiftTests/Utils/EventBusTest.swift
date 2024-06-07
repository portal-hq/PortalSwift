//
//  EventBusTest.swift
//  
//
//  Created by Prakash Kotwal on 07/06/2024.
//
@testable import PortalSwift
import XCTest

final class EventBusTest: XCTestCase {
  var eventBus: EventBus!
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    eventBus = EventBus(label: "TestEventBus")
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    eventBus = nil
  }
  
  func testEmitEvent() throws {
    let expectation = XCTestExpectation(description: "EventBus.emit(event, data)")
    let eventData = "testData"
    
    eventBus.on(event: "testEvent") { data in
      XCTAssertEqual(data as? String, eventData)
      expectation.fulfill()
    }
    
    eventBus.emit(event: "testEvent", data: eventData)
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  func testEmitEventWithNoListeners() throws {
    let expectation = XCTestExpectation(description: "EventBus.emit(event, data) with no listeners")
    expectation.isInverted = true
    
    eventBus.emit(event: "nonExistentEvent", data: "testData")
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  func testOnEvent() throws {
    let expectation = XCTestExpectation(description: "EventBus.on(event, callback)")
    let eventData = "testData"
    
    eventBus.on(event: "testEvent") { data in
      XCTAssertEqual(data as? String, eventData)
      expectation.fulfill()
    }
    
    eventBus.emit(event: "testEvent", data: eventData)
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  func testOnceEvent() throws {
    let expectation = XCTestExpectation(description: "EventBus.once(event, callback)")
    let eventData = "testData"
    
    eventBus.once(event: "testEvent") { data in
      XCTAssertEqual(data as? String, eventData)
      expectation.fulfill()
    }
    
    eventBus.emit(event: "testEvent", data: eventData)
    eventBus.emit(event: "testEvent", data: eventData)
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  func testRemoveListener() throws {
    let expectation = XCTestExpectation(description: "EventBus.removeListener(event)")
    expectation.isInverted = true
    let eventData = "testData"
    
    eventBus.on(event: "testEvent") { data in
      expectation.fulfill()
    }
    
    eventBus.removeListener(event: "testEvent")
    eventBus.emit(event: "testEvent", data: eventData)
    
    wait(for: [expectation], timeout: 1.0)
  }
  
  func testResetEvents() throws {
    let expectation = XCTestExpectation(description: "EventBus.resetEvents()")
    expectation.isInverted = true
    let eventData = "testData"
    
    eventBus.on(event: "testEvent1") { data in
      expectation.fulfill()
    }
    
    eventBus.on(event: "testEvent2") { data in
      expectation.fulfill()
    }
    
    eventBus.resetEvents()
    eventBus.emit(event: "testEvent1", data: eventData)
    eventBus.emit(event: "testEvent2", data: eventData)
    
    wait(for: [expectation], timeout: 1.0)
  }
  
}

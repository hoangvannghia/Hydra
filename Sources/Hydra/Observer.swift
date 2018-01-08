//
//  Observer.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 07/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public typealias Observer<V,E: Swift.Error> = (Event<V,E>) -> Void

/// Represents a type that receives events.
public protocol ObserverProtocol {
	
	/// Type of elements being received.
	associatedtype V
	
	/// Type of error that can be received.
	associatedtype E: Swift.Error
	
	/// Dispatch a new event to the signal.
	///
	/// - Parameter event: event to dispatch.
	func dispatch(event: Event<V,E>)
}

public extension ObserverProtocol {
	
	/// Send the next value to the signal.
	///
	/// - Parameter value: value to send.
	public func send(_ value: V) {
		self.dispatch(event: .next(value))
	}
	
	/// Send failure event to the signal.
	///
	/// - Parameter error: reason of the failure
	public func fail(_ error: E) {
		self.dispatch(event: .failed(error))
	}
	
	/// Send completion event to the signal
	public func complete() {
		self.dispatch(event: .completed)
	}
	
	public func observer() -> Observer<V,E> {
		return self.dispatch
	}
}


// MARK: - ObserverProtocol functions for Void values
public extension ObserverProtocol where V == Void {
	
	/// Convenience method to dispatch `.next` event.
	public func next() {
		next()
	}
	
}

/// SafeObserver is a particular implementation of the ObserverProtocol which
/// guarantees events are sent atomically even in a multi-thread environment.
public class SafeObserver<V,E: Swift.Error>: ObserverProtocol {
	
	/// Observer
	private var observer: Observer<V,E>?
	
	/// Lock which ensures event are dispatched serially
	private let lock: NSRecursiveLock = NSRecursiveLock()
	
	/// Parent disposable
	private let parentDisposable: DisposableProtocol
	
	/// Disposable
	public private(set) var disposable: DisposableProtocol!
	
	public init(disposable: DisposableProtocol, observer: @escaping Observer<V,E>) {
		self.observer = observer
		self.parentDisposable = disposable
		self.disposable = BlockDisposable({ [weak self] in
			self?.observer = nil
			disposable.dispose()
		})
	}
	
	/// Dispatch an event in thread-safe manner
	///
	/// - Parameter event: event
	public func dispatch(event: Event<V,E>) {
		self.lock.lock() // lock
		defer { self.lock.unlock() } // unlock
		
		// If disposed stop dispatching further events
		guard self.disposable.isDisposed == false else { return }
		
		// If observer is available dispatch the event
		if let o = self.observer {
			o(event)
			
			if event.isTerminal { // once terminal event received dispose all
				self.disposable.dispose()
			}
		}
	}
	
	
}

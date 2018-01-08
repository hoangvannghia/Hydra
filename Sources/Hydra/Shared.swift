//
//  Shared.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 07/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// Context in which an action is executed
///
/// - main: main thread
/// - userInteractive: user interactive queue
/// - userInitiated: user initiated queue
/// - utility: utility queue
/// - background: background queue
/// - custom: custom queue
public enum Context {
	case main
	case userInteractive
	case userInitiated
	case utility
	case background
	case custom(queue: DispatchQueue)
	
	public var queue: DispatchQueue {
		switch self {
		case .main: return .main
		case .userInteractive: return .global(qos: .userInteractive)
		case .userInitiated: return .global(qos: .userInitiated)
		case .utility: return .global(qos: .utility)
		case .background: return .global(qos: .background)
		case .custom(let queue): return queue
		}
	}
	
}

// MARK: - Extension to DispatchQueue
public extension DispatchQueue {
	
	/// Schedule given block for execution after given interval passes.
	/// Scheduled execution can be cancelled by disposing the returned disposable.
	public func disposable(after interval: Double, block: @escaping () -> (Void)) -> DisposableProtocol {
		let disposable = Disposable()
		self.asyncAfter(deadline: .now() + interval) {
			if disposable.isDisposed == false {
				block()
			}
		}
		return disposable
	}
	
}

/// This is an error which cannot be instantiated.
/// It's used to define a Signal which cannot fail.
public enum NoError: Error { }

/// GCDTimer is a class used to produce a precise timer which execute
/// a specified function at given time interval.
public class GCDTimer {
	
	/// Define an action executed by the timer itself
	public typealias Action = ((GCDTimer?) -> ())
	
	/// Action to execute at specified intervals
	private var action: Action
	
	/// Timer interval
	public private(set) var interval: DispatchTimeInterval
	
	/// Timer
	private var timer: DispatchSourceTimer? = nil
	
	/// Queue in which the timer callback will be executed
	private var queue: DispatchQueue? = nil
	
	/// Initialize a new timer with specified interval.
	///
	/// - Parameters:
	///   - interval: interval of the timer expressed in seconds
	///   - start: `true` to start timer automatically just after the initialization of the class. To manually start a timer call `start()`
	///   - action: action callback to execute
	public init(_ interval: Int, start: Bool = true, _ action: @escaping Action) {
		self.interval = .seconds(interval)
		self.action = action
		if start == true { self.start() }
	}
	
	/// Start (or restart) timer
	public func start() {
		self.queue = DispatchQueue(label: "com.hydra.timer")
		// Recreate timer object
		self.timer?.cancel()
		self.timer = DispatchSource.makeTimerSource(flags: .strict, queue: self.queue)
		self.timer?.schedule(deadline: .now(), repeating: self.interval, leeway: .milliseconds(100))
		self.timer?.setEventHandler(handler: { [weak self] in
			self?.action(self)
		})
		self.timer?.resume()
	}
	
	/// Stop timer
	public func stop() {
		self.timer?.cancel()
		self.timer = nil
		self.queue = nil
	}
}

/// Optional protocol
public protocol OptionalProtocol {
	associatedtype Wrapped
	
	/// Unwrap optional type
	var unwrapped: Optional<Wrapped> { get }
	
	/// Init with nil
	///
	/// - Parameter nilLiteral: nil
	init(nilLiteral: ())
	
	/// Init with a value
	///
	/// - Parameter some: value to keep
	init(_ some: Wrapped)
}

extension Optional: OptionalProtocol {
	
	/// Unwrap
	public var unwrapped: Optional<Wrapped> {
		return self
	}
	
}

func ==<O: OptionalProtocol>(lhs: O, rhs: O) -> Bool where O.Wrapped: Equatable {
		return lhs.unwrapped == rhs.unwrapped
}

func !=<O: OptionalProtocol>(lhs: O, rhs: O) -> Bool where O.Wrapped: Equatable {
		return !(lhs == rhs)
}


//
//  SignalProtocol+Creation.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 07/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public extension SignalProtocol {
	
	/// Create a new signal which emits a single value then complete.
	///
	/// - Parameter value: value to emit
	/// - Returns: signal
	public static func just(_ value: V) -> Signal<V,E> {
		return Signal { obs in
			obs.send(value) // emit value
			obs.complete() // complete
			return NotDisposable
		}
	}
	
	/// Create a new signal which completes without emitting any value.
	///
	/// - Returns: signal
	public static func completed() -> Signal<V,E> {
		return Signal { obs in
			obs.complete() // just complete
			return NotDisposable
		}
	}
	
	/// Create a new signal which fails with given error without emitting any value.
	///
	/// - Parameter error: error used to fail.
	/// - Returns: signal
	public static func failed(_ error: E) -> Signal<V,E> {
		return Signal { obs in
			obs.fail(error)
			obs.complete()
			return NotDisposable
		}
	}
	
	
	/// Create a new signal which emits given sequence of events then complete.
	///
	/// - Parameter sequence: sequence to emits.
	/// - Returns: signal
	public static func sequence<S: Sequence>(_ sequence: S) -> Signal<V,E> where S.Iterator.Element == V {
		return Signal { obs in
			sequence.forEach { obs.send($0) }
			obs.complete()
			return NotDisposable
		}
	}
	
	/// Create a new signal which never complets and does not emits events.
	///
	/// - Returns: signal
	public static func endless() -> Signal<V,E> {
		return Signal { obs in
			return NotDisposable
		}
	}


	/// Create a new signal which call a generator callback at regular intervals.
	///
	/// - Parameter seconds: interval between calls, expressed in seconds.
	/// - Parameter context: context in which the callback is called, if not specified `.background` is used.
	/// - Parameter generator: callback functions.
	/// - Return: signal
	public func scheduled(seconds interval: Int, context: Context = .background, _ generator: @escaping (() throws -> V)) -> Signal<V,E> {
		return Signal { obs in
			let timer = GCDTimer.init(interval) { t in
				context.queue.async {
					do {
						obs.send(try generator())
					} catch let err {
						if let e = err as? E { obs.fail(e) }
						else { obs.complete() }
					}
				}
			}
			return BlockDisposable.init {
				timer.stop()
			}
		}
	}

	/// Create a new signal which emits a value after a specified amount of seconds.
	///
	/// Parameter seconds: number of seconds before emitting the value.
	/// Parameter value: value to be emitted.
	/// Parameter context: context in which the value is emitted, if not speciried `.background` is used.
	public func after(seconds: Double, emit value: V, context: Context = .background) -> Signal<V,E> {
		return Signal { obs in
			let disposable = Disposable()
			context.queue.asyncAfter(deadline: (.now() + seconds), execute: {
				guard disposable.isDisposed == false else { return }
				obs.send(value)
				obs.complete()
			})
			return disposable
		}
	}
	
}

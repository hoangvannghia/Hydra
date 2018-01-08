//
// Created by danielemargutti on 08/01/2018.
// Copyright (c) 2018 Hydra. All rights reserved.
//

import Foundation

// MARK: - SignalProtocol Extensions (GENERIC)
public extension SignalProtocol {
	
	/// Convert the protocol to a concrete Signal class with the same error and value types.
	///
	/// - Returns: signal
	public func signal() -> Signal<V,E> {
		guard let signal = self as? Signal<V,E> else {
			return Signal { return self.observe($0) } // just forward messages
		}
		return signal // just return self
	}
	
	/// Restart operation in case of failure for a given amount of attempts.
	/// If the maximum number of attempts has been reached last error (or if not `nil`, `error`) is dispatched.
	///
	/// - Parameters:
	///   - attempts: number of attempts
	///   - error: if specified this is the error dispatched if maximum number of attempts has been reached. If `nil` latest error is dispatched.
	/// - Returns: signal
	public func retry(_ attempts: Int, error fixedError: E?) -> Signal<V,E> {
		guard attempts > 0 else { return self.signal() } // return the same signal
		
		return Signal { obs in
			var remaining: Int = attempts
			let serialDisposable = SafeDisposable()
			var attempt: (() -> Void)?
			attempt = {
				serialDisposable.linkedDisposable?.dispose()
				serialDisposable.linkedDisposable = self.subscribe { event in
					switch event {
					case .next(let v):
						// Attempt succeded, just forward the value
						obs.send(v)
					case .completed:
						// Attempt succeded, just forward the completion mark of the stream
						attempt = nil
						obs.complete()
					case .failed(let e):
						// Attempt failed
						guard remaining > 0 else {
							attempt = nil // stop re-executing the job
							obs.fail( (fixedError ?? e) ) // dispatch fixed error or, if not specified, last failure error
							return
						}
						// make another attempt
						remaining -= 1
						attempt?()
					}
				}
			}
			attempt?()
			return BlockDisposable {
				serialDisposable.dispose()
				attempt = nil // cancel the attempt operation
			}
		}
	}
	
	/// Reduce signal events to a single event of type `FinalValue` by applying the `combine` function.
	/// The first event of the reduce is the initial value provided, subsequent values are the result of
	/// the current accumulator status combined with the last event received.
	///
	/// - Parameters:
	///   - initial: initial value of the reduce
	///   - combine: combine function
	/// - Returns: a new signal
	public func reduce<FinalValue>(_ initial: FinalValue, _ combine: @escaping (FinalValue,V) -> (FinalValue)) -> Signal<FinalValue,E> {
		return Signal { obs in
			var accumulator: FinalValue = initial
			obs.send(accumulator) // dispatch the initial value first time
			return self.subscribe { event in
				// on each new event combine the value with current state of the accumulator
				// clearly only for `.next` values.
				switch event {
				case .failed(let e):		obs.fail(e)
				case .completed:			obs.complete()
				case .next(let v):
					accumulator = combine(accumulator, v) // combine with previous combined result
					obs.send(accumulator) // dispatch combined result
				}
			}
		}
	}
	
	/// Dispatch given error if signal does not resolve in seconds passed.
	///
	/// - Parameters:
	///   - seconds: timeout seconds
	///   - error: error to generate in case of timeout
	/// - Returns: signal
	public func timeout(_ seconds: Double, error: E) -> Signal<V,E> {
		return Signal { obs in
			var isCompleted: Bool = false
			let timeoutDisposable = Context.background.queue.disposable(after: seconds, block: { // start timeout
				if !isCompleted { // if operation was not completed yet we fail it with given timeout
					obs.fail(error)
				}
			})
			return self.subscribe { event in
				// an event has been received
				obs.dispatch(event: event) // ...dispatch event
				isCompleted = event.isTerminal // ...mark it as completed
				timeoutDisposable.dispose() // cancel timeout timer
			}
		}
	}
	
	/// Delay the execution of signal event's stream by a given amount of second.
	/// All messages received during the "blackout" interval are sent in sequence after the amount of delay.
	///
	/// - Parameter seconds: seconds to wait before dispatching events
	/// - Parameter context: context in which the delay is executed, if not specified `.background` is used.
	/// - Returns: signal
	public func delay(seconds: Double, context: Context = .background) -> Signal<V,E> {
		return Signal { obs in
			return self.subscribe { event in
				context.queue.asyncAfter(deadline: .now() + seconds, execute: {
					obs.dispatch(event: event)
				})
			}
		}
	}

    /// Throttle the signal to emit at most one value per given `seconds` interval.
    /// Note: `.complete` and `fail` events are dispatched normally.
    ///
    /// Parameter seconds: minimum interval required
    /// Return: signal
    public func throttle(seconds: Double) -> Signal<V,E> {
        return Signal { obs in
            var lastEventTime: DispatchTime? = nil
            return self.subscribe { event in
                switch event {
                    case .next(let v):
                        let now = DispatchTime.now()
                        if (lastEventTime == nil) || (now.rawValue > (lastEventTime! + seconds).rawValue) {
                            // has passed enough time to dispatch a new signal or this is the first time
                            lastEventTime = now
                            obs.send(v)
                        } // else ignore this message
                    default: // other messages are dispatched normally
                        obs.dispatch(event: event)
                }
            }
        }
    }

    /// Emit an element only if `seconds` time interval passes without emitting another element.
    /// Note: This is valid only for `.next` event.
    ///
    /// Parameter seconds: time interval
    /// Parameter context: context in which the debounce is executed.
    /// Return: signal
    public func debounce(seconds: Double, context: Context = .background) -> Signal<V,E> {
        return Signal { obs in
            var disposable: DisposableProtocol? = nil
            var previousValue: V? = nil

            return self.subscribe { event in
                disposable?.dispose()

                switch event {
                    case .failed(let e):    obs.fail(e)
                    case .completed:
                        if let v = previousValue {
                            obs.send(v)
                            obs.complete()
                        }
                    case .next(let v):
                        previousValue = v
						disposable = context.queue.disposable(after: seconds, block: {
                            if let v = previousValue {
                                obs.send(v)
                                previousValue = nil
                            }
                        })
                }
            }
        }
    }

    /// Allows to filter received value using a boolean function test.
    /// Note: this is valid only for `.next` event, all `.complete` and `.fail` are dispatched normally.
    ///
    /// Parameter function: test function; `.next` values are passed over only if test returns `true`.
    /// Return: signal
    public func filter(_ function: @escaping ((V) -> Bool)) -> Signal<V,E> {
        return Signal { obs in
            return self.subscribe { event in
                switch event {
                    case .next(let v):
                        if function(v) == true { obs.send(v) } // only passed signal are dispatched over
                    default:
                        obs.dispatch(event: event)
                }
            }
        }
    }

    /// Filter the signal by skipping (and ignoring) first `count` received values (`.next` events).
    /// Note: `.complete` and `.fail` events are dispatched normally.
    ///
    /// Parameter count: number of first `.next` events to ignore.
    /// Return: signal
    public func skip(first count: Int) -> Signal<V,E> {
        return Signal { obs in
            var remaining: Int = count
            return self.subscribe { event in
                switch event {
                    case .next(let v):
                        if remaining > 0 { remaining-=1 }
                        else { obs.send(v) }
                    default:
                        obs.dispatch(event: event)
                }
            }
        }
    }

    /// Emit first element and then all elements that are not equal to their predecessor(s).
    /// This filter can be used when V values are not conform to `Equatable` protocol.
    ///
    /// Parameter withFunction: function used to compare two elements
    /// Return: signal
    public func distinct(withFunction function: @escaping (V,V) -> Bool) -> Signal<V,E> {
        return Signal { obs in
            var last: V? = nil
            return self.subscribe { event in
                switch event {
                case .next(let v):
                    let previousValue = last
                    last = v
                    if previousValue == nil || function(previousValue!, v) {
                        obs.send(v)
                    }
                default:
                    obs.dispatch(event: event)
                }
            }
        }
    }

    /// Emit only the last `count` values produced by the signal, then complete.
    ///
    /// Parameter count: number of latest values to keep and dispatch after completion of the signal itself. If not specified only last is kept.
    /// Return: signal
    public func last(count: Int = 1) -> Signal<V,E> {
        return Signal { obs in
            var valuesBuffer: [V] = []
            return self.subscribe { event in
                switch event {
                case .failed(let e):
                    obs.fail(e)
                case .next(let v):
                    if (valuesBuffer.count + 1) > count { // keep the buffer with the same size
                        valuesBuffer.removeFirst((valuesBuffer.count - count + 1))
                    }
                    valuesBuffer.append(v) // append new item
                case .completed:
                    // when completion event i
                    valuesBuffer.forEach {
                        obs.send($0)
                    }
                    obs.complete()
                }
            }
        }
    }

    /// Emit only first `count` values of the signal and then complete.
    /// This is valid only for `.next` events, `.complete` and `.fail` are dispatched normally.
    ///
    /// Parameter count: number of values to dispatch before complete the signal. If not specified only the first value is send, then signal completes.
    public func first(count: Int = 1) -> Signal<V,E> {
        return Signal { obs in
            guard count > 0 else { // no values to keep, just return complete
				obs.complete()
				return NotDisposable
			}
			
            var kept: Int = 0
            let disposable = SafeDisposable()
            disposable.linkedDisposable = self.subscribe { event in
                switch event {
                    case .next(let v):
                        // until first `count` messages are not dispatched, we'll dispatch it normally
                        guard kept < count else { return } // otherwise we'll ignore all other values
                        kept += 1
                        obs.send(v)
                    default: // other events are dispatched normally
                        obs.dispatch(event: event)
                }
            }
            return disposable
        }
    }

    /// Emit only `.next` events and ignore all terminal events (`.complete` and `.fail`).
    public func justValues() -> Signal<V,E> {
        return Signal { obs in
            return self.subscribe { event in
                if case .next(let v) = event { obs.send(v) } // dispatch only `.next` values
                // ...and ignore all other events
            }
        }
    }

}

// MARK: - SignalProtocol Extension (EQUATABLE)

public extension SignalProtocol where V: Equatable {

    /// Emit first element and then all elements that are not equal to their predecessor(s).
    /// Each value must be conform to `Equatable` protocol in order to be compared correctly.
    /// If your value is not conform to this protocol use `distinct(withFunction:)` function.
    /// Return: signal
    public func distinct() -> Signal<V,E> {
        return Signal { obs in
            var previousValue: V? = nil
            return self.subscribe { event in
                switch event {
                    case .next(let v):
                        let prevLast = previousValue
                        previousValue = v
                        if prevLast == nil || prevLast != v {
                            obs.send(v) // is different (or this is the first message), we can dispatch it
                        }
                    default:
                        obs.dispatch(event: event)
                }
            }
        }
    }

}

// MARK: - SignalProtocol Extension (OPTIONAL)
public extension SignalProtocol where V: OptionalProtocol {
	
	/// Suppress al nil values for a signal where the value object type can be nil.
	///
	/// - Returns: signal with only valid values
	public func filterNil() -> Signal<V.Wrapped,E> {
        return Signal { obs in
			self.subscribe { event in
				switch event {
				case .failed(let e):		obs.fail(e)
				case .completed:			obs.complete()
				case .next(let v):
					guard let unwrapped = v.unwrapped else { return } // ignore nil values
					obs.send(unwrapped)
				}
			}
        }
    }
	
	/// Suppress all `nil` values by replacing `nil` values with specified non-nil value.
	///
	/// - Parameter value: value used to replace `nil` occurences during the stream
	/// - Returns: signal of unwrapped non `nil` values
	public func filterNil(byReplacingWith value: V.Wrapped) -> Signal<V.Wrapped,E> {
		return Signal { obs in
			self.subscribe { event in
				switch event {
				case .failed(let e):		obs.fail(e)
				case .completed:			obs.complete()
				case .next(let v):
					guard let unwrapped = v.unwrapped else { obs.send(value); return; } // send replaced value
					obs.send(unwrapped) // value is unwrapped and contain a valid value, send it
				}
			}
		}
	}

}

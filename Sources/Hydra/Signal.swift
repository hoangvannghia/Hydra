//
//  Signal.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 07/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// Signal represent a stream/sequence of values produced over the time.
/// Each event streamed by a signal instance can be
public struct Signal<V,E: Swift.Error>: SignalProtocol {
	
	/// SignalProducer is responsibile to generate new events for the signal.
	/// It's basically a closure where the trasmitter is passed inside and it can be
	/// used to generate new events.
	public typealias SignalProducer = ((SafeObserver<V,E>) -> (DisposableProtocol))
	
	/// This is the producer of the Signal.
	/// The task of the producer is to call a function which is responsible to trasnmit
	/// new events via the signal itself.
	private let producer: SignalProducer
	
	/// Initialize a new signal with given producer callback
	///
	/// - Parameter producer: producer of the events
	public init(_ producer: @escaping SignalProducer) {
		self.producer = producer
	}
	
	/// Create a new Signal by running the producer's code in background queue.
	/// This is a shortcut for `Signal(...).run(in: .background)`.
	///
	/// - Parameter producer: producer of the events
	/// - Returns: a signal
	public static func inBackground<V,E>(_ producer: @escaping ((SafeObserver<V,E>) -> (DisposableProtocol))) -> Signal<V,E> {
		return Signal<V,E>(producer).run(in: .background)
	}
	
	/// Create a new Signal by running the producer's code in given context.
	/// A context is a shortcut for a Grand Central Dispatch Queue-
	///
	/// - Parameters:
	///   - context: context where the producer is executed
	///   - producer: producer's callback
	/// - Returns: a signal
	public static func inContext(_ context: Context, _ producer: @escaping ((SafeObserver<V,E>) -> (DisposableProtocol))) -> Signal<V,E> {
		return Signal<V,E>(producer).run(in: context)
	}
	
	/// Register a new observer to receive stream of events from the signal instance.
	///
	/// - Parameter observer: observer callback
	/// - Returns: disposable to cancel the observationx
	public func subscribe( _ observer: @escaping Observer<V,E>) -> DisposableProtocol {
		// Create a new disposable
		let disposable = SafeDisposable()
		let observer = SafeObserver(disposable: disposable, observer: observer) // Create a safe observer to dispatch event serially
		// Link disposable to producer's disposable so, on dispose, also the observer's disposable
		// will be disposed too.
		disposable.linkedDisposable = self.producer(observer)
		return observer.disposable
	}
	
}


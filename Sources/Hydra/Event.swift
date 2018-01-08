//
//  Event.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 07/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// This is the event a signal can send.
///
/// - next: an event that carries the next value produced for the signal.
/// - failed: an event which represent an error. signal is automatically closed after this event.
/// - completed: an event that marks the completion of the signal's sequence.
public enum Event<V,E: Swift.Error> {
	case next(V)
	case failed(E)
	case completed
	
	/// Return the value carried by the event.
	/// It return a valid value only for `next` event, otherwise it return `nil`.
	public var value: V? {
		guard case .next(let v) = self else { return nil }
		return v
	}
	
	/// Return the error carried by the event; it return a non `nil` value only for `failed` event's type.
	public var error: E? {
		guard case .failed(let e) = self else { return nil }
		return e
	}
	
	/// Return `true` if event marks the completion of the signal.
	public var isTerminal: Bool {
		guard case .next = self else { return true }
		return false
	}
}

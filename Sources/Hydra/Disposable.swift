//
//  Disposable.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 07/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// Disposable are object used to keep a reference from an event observation or property bind.
/// When a new observation/bind take places it return a Disposable object; user can use this object
/// to cancel subscriptions (by calling its `dispose()` function).
/// A signal is guaranteed not to fire any event after is has been disposed.
public protocol DisposableProtocol {
	
	/// Cancel observation/bind
	func dispose()
	
	/// Return `true` if disposable has been disposed, `false` if it still in place.
	var isDisposed: Bool { get }
	
}


// MARK: - Disposable Extension
public extension DisposableProtocol {
	
	/// Put the disposable in the given bag. Disposable will be disposed when
	/// the bag is either deallocated or disposed.
	public func dispose(inBag bag: DisposeBagProtocol) {
		bag.add(self)
	}
	
}

/// Simple Disposable class.
/// This disposable is not thread safe.
public final class Disposable: DisposableProtocol {
	
	/// Is disposed?
	public private(set) var isDisposed: Bool = false
	
	/// Dispose
	public func dispose() {
		self.isDisposed = true
	}
	
	/// Initialize a new Disposable with given status.
	///
	/// - Parameter disposed: disposed, if not specified `false` is set as initial status.
	init(disposed: Bool = false) {
		self.isDisposed = disposed
	}
	
}

/// SafeDisposable class implements a serial disposable which, upon dispose request,
/// dispose a linked disposed in order.
public final class SafeDisposable: DisposableProtocol {
	
	/// Is disposed?
	public private(set) var isDisposed: Bool = false
	
	/// Lock used to keep the dispose action thread-safe
	private let lock: NSRecursiveLock = NSRecursiveLock()
	
	/// Optional linked disposable
	public var linkedDisposable: DisposableProtocol? {
		didSet {
			// thread safe operation
			self.lock.lock() // ...lock
			defer { self.lock.unlock() } // ...unlock at the end of the operation
			if isDisposed { linkedDisposable?.dispose() } // auto-dispose if disposable was already disposed
		}
	}
	
	/// Initialize a new thread-safe Disposable with optional linked disposable.
	///
	/// - Parameter linked: optional linked disposable
	public init(_ linked: DisposableProtocol? = nil) {
		self.linkedDisposable = linked
	}
	
	/// Dispose operation, dispose the disposable and optionally linked disposable in thread-safe manner
	public func dispose() {
		self.lock.lock() // lock
		defer { self.lock.unlock() } // unlock at the end
		guard self.isDisposed == false else { return }
		// dispose all if not disposed yet
		self.isDisposed = true
		self.linkedDisposable?.dispose()
	}
	
}

/// BlockDisposable allows to specify a block to be executed on dispose.
/// This class is thread safe for dipose.
public final class BlockDisposable: DisposableProtocol {
	
	/// Typealias of the block to execute
	public typealias Handler = (() -> (Void))
	
	/// Action to execute on dispose
	private var action: Handler?
	
	/// Lock for thread-safe support
	private var lock: NSRecursiveLock = NSRecursiveLock()
	
	/// Is disposed?
	/// Instance is disposed if associated action was executed (because we'll mark it as `nil`).
	public var isDisposed: Bool {
		return (self.action == nil)
	}
	
	/// Initialize a new Disposable with associated action on dispose.
	///
	/// - Parameter action: action
	public init(_ action: @escaping Handler) {
		self.action = action
	}
	
	/// Dispose
	public func dispose() {
		self.lock.lock() // lock
		defer { self.lock.unlock() } // ...unlock
		if let action = self.action { // if an action is associated execute it
			self.action = nil // mark as disposed
			action() // execute action
		}
	}
	
}

/// Shortcut to non disposable Disposable (`Undisposable` class)
let NotDisposable: Undisposable = Undisposable.instance

/// This represent a disposable which cannot be disposed.
public struct Undisposable: DisposableProtocol {
	
	/// Singleton
	public static let instance: Undisposable = Undisposable()
	
	/// Is disposed always return false
	public var isDisposed: Bool = false
	
	/// Dispose (does nothing)
	public func dispose() {}
	
	/// Private initialization
	private init() {}
	
}


/// DisposableBagProtocol implements a list of Disposable
public protocol DisposeBagProtocol: DisposableProtocol {
	
	/// Add a new disposable
	///
	/// - Parameter item: disposable to add into the list
	func add(_ item: DisposableProtocol)
	
}


/// DisposeBag implements a list of Dispose
public final class DisposeBag: DisposeBagProtocol {
	
	/// List of DisposableProtocol elements
	private var list: [DisposableProtocol] = []
	
	/// Return `true` when all disposable has been disposed
	public var isDisposed: Bool {
		return (self.list.count == 0)
	}
	
	/// Add new item to DisposableProtocol
	///
	/// - Parameter item: dispose to add
	public func add(_ item : DisposableProtocol) {
		self.list.append(item)
	}
	
	/// Add new items to DisposableProtocol
	///
	/// - Parameter items: dispose list to add
	public func add(_ items: [DisposableProtocol]) {
		self.list.append(contentsOf: items)
	}
	
	/// Dispose all disposable
	public func dispose() {
		self.list.forEach { $0.dispose() }
		self.list.removeAll()
	}
	
	/// Auto dispose on deinit
	deinit {
		self.dispose()
	}
	
	public static func += (lhs: DisposeBag, rhs: DisposableProtocol) {
		lhs.add(rhs)
	}
	
	public static func += (lhs: DisposeBag, rhs: [DisposableProtocol]) {
		lhs.add(rhs)
	}
	
}

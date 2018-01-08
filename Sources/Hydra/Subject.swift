//
//  Subject.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 08/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public protocol SubjectProtocol: SignalProtocol, ObserverProtocol {
	
}

private struct TokenGenerator {
	typealias Token = UInt64
	
	private var token: Token = 0
	
	public mutating func nextToken() -> Token {
		let assignedToken = self.token
		self.token += 1
		return assignedToken
	}
}

public class Subject<V,E: Swift.Error>: SubjectProtocol {
	
	private var tokenGenerator: TokenGenerator = TokenGenerator()
	
	private var observersList: [(TokenGenerator.Token, Observer<V,E>)] = []
	
	public private(set) var isTerminal: Bool = false
	
	public let lock: NSRecursiveLock = NSRecursiveLock()
	public let disposeBag: DisposeBag = DisposeBag()
	
	public init() {
		
	}
	
	public func on(_ event: Event<V,E>) {
		self.lock.lock()
		defer { self.lock.unlock() }
		guard self.isTerminal == false else {
			return
		}
		self.dispatch(event: event)
	}
	
	public func dispatch(event: Event<V,E>) {
		self.observersList.forEach { _,observer in
			observer(event)
		}
	}
	
	public func subscribe(_ observer: @escaping Observer<V,E>) -> DisposableProtocol {
		self.lock.lock()
		defer { self.lock.unlock() }
		let assignedToken = self.tokenGenerator.nextToken()
		
		self.observersList.append( (assignedToken, observer) )
		return BlockDisposable { [weak self] in
			guard let idx = self?.observersList.index(where: { $0.0 == assignedToken }) else {
				return
			}
			self?.observersList.remove(at: idx)
		}
	}
	
}

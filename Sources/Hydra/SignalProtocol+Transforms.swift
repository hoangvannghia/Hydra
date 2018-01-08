//
// Created by danielemargutti on 08/01/2018.
// Copyright (c) 2018 Hydra. All rights reserved.
//

import Foundation

public extension SignalProtocol {

    /// Batch received events in a buffer array with specified size.
    /// When buffer is full signal will emit a new `.next` event with
    /// stored array, then flush saved buffer waiting for next entries.
    public func hold(buffer size: Int) -> Signal<[V],E> {
        return Signal { obs in
            var bufferArray: [V] = []
            return self.subscribe { event in
                switch event {
                    case .completed:        obs.complete()
                    case .failed(let e):    obs.fail(e)
                    case .next(let v):
                        bufferArray.append(v) // append to buffer
                        if bufferArray.count == size { // if full, send buffer and flush array
                            obs.send(bufferArray)
                            bufferArray.removeAll()
                        }
                }
            }
        }
    }

    /// Transform each `.next` element received by the signal in another type of event using
    /// given `transformer` function.
    /// Transformer function may throws; in this case if the error is a valid Swift.Error signal fails with that error,
    /// otherwise it will return `complete`.
    ///
    /// Parameter transformer: transformer function used to transform object of type V to another object of type NewValue, may fail.
    public func map<NewValue>(_ transformer: @escaping (V) throws -> NewValue) -> Signal<NewValue,E> {
        return Signal { obs in
            return self.subscribe { event in
                switch event {
                    case .failed(let e):    obs.fail(e)
                    case .completed:        obs.complete()
                    case .next(let v):
                        do {
                            obs.send(try transformer(v))
                        } catch let err {
                            if let e = err as? E { obs.fail(e) }
                            else { obs.complete() }
                        }
                }
            }
        }
    }

    /// Maps each value into an optional type and propagate only unwrapped results by ignoring nil and throwed transforms.
    ///
    /// Parameter transformer: transformer function used to transform object of type V into another of type NewValue. Only non nil value are passed.
    public func flatMap<NewValue>(_ transformer: @escaping (V) throws -> NewValue) -> Signal<NewValue,E> {
        return Signal { obs in
            return self.subscribe { event in
                switch event {
                    case .failed(let e):    obs.fail(e)
                    case .completed:        obs.complete()
                    case .next(let v):
                        if let transformedValue = try? transformer(v) {
                            obs.send(transformedValue)
                        }
                }
            }
        }
    }

    /// Maps only error events and transform them to another error type using given transform function.
    ///
    /// Parameter errTransformer: transformer function to transform an error of type E to another error of type NewError
    public func mapError<NewError>(_ errTransformer: @escaping (E) -> NewError) -> Signal<V,NewError> {
        return Signal { obs in
            return self.subscribe { event in
                switch event {
                    case .next(let v):      obs.send(v)
                    case .completed:        obs.complete()
                    case .failed(let e):    obs.fail(errTransformer(e))
                }
            }
        }
    }

    /// Recover an error by transforming it to a valid value for a signal.
    /// Returned signal cannot produce further error (has `NoError` type).
    ///
    /// Parameter recover: function used to recover the error and transform it to a valid value.
    public func recover(_ recover: @escaping (E) -> (V)) -> Signal<V,NoError> {
        return Signal { obs in
            return self.subscribe { event in
                switch event {
                    case .next(let v):      obs.send(v)
                    case .completed:        obs.complete()
                    case .failed(let e):    obs.send(recover(e))
                }
            }
        }
    }

}

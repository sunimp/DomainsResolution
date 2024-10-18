//
//  AsyncResolver.swift
//  DomainsResolution
//
//  Created by Sun on 2021/9/28.
//

import Foundation

class AsyncResolver {
    // MARK: Nested Types

    typealias GeneralFunction<T> = () throws -> T

    // MARK: Properties

    let asyncGroup = DispatchGroup()

    // MARK: Functions

    func safeResolve<T>(
        listOfFunc: [GeneralFunction<T>]
    ) throws
        -> T {
        let results = try resolve(listOfFunc: listOfFunc)
        return try parseResult(results)
    }

    func resolve<T>(
        listOfFunc: [GeneralFunction<T>]
    ) throws
        -> [UNSLocation: AsyncConsumer<T>] {
        var results: [UNSLocation: AsyncConsumer<T>] = [:]
        var functions: [UNSLocation: GeneralFunction<T>] = [
            .layer2: listOfFunc[1], .layer1: listOfFunc[0],
        ]
            
        if listOfFunc.count > 2 {
            functions[.znsLayer] = listOfFunc[2]
        }
            
        let queue = DispatchQueue(label: "LayerQueque")
        for function in functions {
            asyncGroup.enter()
            DispatchQueue.global().async { [weak self] in
                guard let self else {
                    return
                }
                do {
                    let value = try function.value()
                    queue.sync {
                        results[function.key] = (value, nil)
                    }
                } catch {
                    queue.sync {
                        results[function.key] = (nil, error)
                    }
                }
                asyncGroup.leave()
            }
        }
        let semaphore = DispatchSemaphore(value: 0)
        asyncGroup.notify(queue: .global()) {
            semaphore.signal()
        }
        semaphore.wait()
        return results
    }

    private func parseResult<T>(_ results: [UNSLocation: AsyncConsumer<T>]) throws -> T {
        // filter out results that were not provided (in case some methods are not supported by some providers)
        let resultsOrder = [UNSLocation.layer2, UNSLocation.layer1, UNSLocation.znsLayer]
            .filter { v in results.keys.contains(v) }
        
        // Omit the last result since we would have to return it regardless
        for resultKey in resultsOrder.dropLast() {
            let result = results[resultKey]!
            
            if let error = result.1 {
                if !Utillities.isUnregisteredDomain(error: error) {
                    throw error
                }
            } else if let answer = result.0 {
                return answer
            }
        }
        
        let result = results[resultsOrder.last!]!
        
        if let error = result.1 {
            throw error
        }
        return result.0!
    }
}

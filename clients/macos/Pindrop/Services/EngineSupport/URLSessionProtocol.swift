//
//  URLSessionProtocol.swift
//  Pindrop
//
//  Created on 2026-03-29.
//

import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

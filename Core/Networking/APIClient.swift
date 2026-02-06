//
//  APIClient.swift
//  tracme-alpha
//
//  Created by Walter Karabin on 2026-01-23.
//


import Combine
import Foundation

/// Protocol for AuthManager dependency injection
protocol AuthProvider {
  var accessToken: String? { get }
  var refreshToken: String? { get }
  func refreshAccessToken() async -> Bool
  func removeAccessToken()
}

/// APIClient handles authenticated requests and token refresh
class APIClient {
  private let authProvider: AuthProvider
    
    // 1. Add this line
    static let shared = APIClient(authProvider: AuthManager.shared)

  init(authProvider: AuthProvider) {
    self.authProvider = authProvider
  }

  /// Generic API request with automatic JWT management
  func request<T: Decodable>(
    endpoint: URL,
    method: String = "GET",
    body: Data? = nil,
    headers: [String: String] = [:],
    responseType: T.Type
  ) async throws -> T {
    var request = URLRequest(url: endpoint)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Attach access token if available
    if let token = authProvider.accessToken {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    // Add custom headers
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
      print("APIClient: Access token unauthorized, attempting to refresh.")
      // Try to refresh token and retry once
      let refreshed = await authProvider.refreshAccessToken()
      guard refreshed, let newToken = authProvider.accessToken else {
        // Remove current invalid token
        authProvider.removeAccessToken()
        print("APIClient: Access token refresh failed, logging out user.")
        throw APIClientError.unauthorized
      }
      // Retry with new token
      var retryRequest = request
      retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
      let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
      if let retryHttpResponse = retryResponse as? HTTPURLResponse {
        if !(200...299).contains(retryHttpResponse.statusCode) {
          let responseString = String(data: retryData, encoding: .utf8)
          throw APIClientError.serverError(
            statusCode: retryHttpResponse.statusCode, message: responseString)
        }
      }
      do {
        return try JSONDecoder().decode(T.self, from: retryData)
      } catch {
        // Include raw response when decoding fails
        let responseString = String(data: retryData, encoding: .utf8)
        throw APIClientError.decodingError(message: responseString)
      }
    }
    if let httpResponse = response as? HTTPURLResponse {
      guard (200...299).contains(httpResponse.statusCode) else {
        let responseString = String(data: data, encoding: .utf8)
        throw APIClientError.serverError(
          statusCode: httpResponse.statusCode, message: responseString)
      }
    }
    do {
      // print("APIClient: data received: \(String(data: data, encoding: .utf8) ?? "nil")")
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      let responseString = String(data: data, encoding: .utf8)
      throw APIClientError.decodingError(message: responseString)
    }
  }

  /// Upload raw data (e.g. image) to the given endpoint while including the access token.
  /// Returns the raw response data and HTTPURLResponse so the caller can examine status + body.
  /// On 401, attempts token refresh and retries once.
  func upload(
    data: Data,
    endpoint: URL,
    method: String = "POST",
    contentType: String = "application/octet-stream",
    headers: [String: String] = [:]
  ) async throws -> (Data, HTTPURLResponse) {
    var request = URLRequest(url: endpoint)
    request.httpMethod = method
    request.httpBody = nil
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    if let token = authProvider.accessToken {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }

    var (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
    var httpResponse = response as? HTTPURLResponse

    if httpResponse?.statusCode == 401 {
      let refreshed = await authProvider.refreshAccessToken()
      guard refreshed, let newToken = authProvider.accessToken else {
        authProvider.removeAccessToken()
        throw APIClientError.unauthorized
      }
      var retryRequest = request
      retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
      (responseData, response) = try await URLSession.shared.upload(for: retryRequest, from: data)
      httpResponse = response as? HTTPURLResponse
    }

    guard let final = httpResponse else {
      throw APIClientError.serverError(statusCode: -1, message: "Invalid response")
    }
    return (responseData, final)
  }

  /// Upload a file using multipart/form-data with a single `file` field (or custom fieldName).
  func uploadMultipart(
    data: Data,
    filename: String,
    fieldName: String = "file",
    mimeType: String,
    endpoint: URL,
    additionalFields: [String: String] = [:]
  ) async throws -> (Data, HTTPURLResponse) {
    let boundary = "Boundary-\(UUID().uuidString)"
    var body = Data()

    // additional form fields
    for (key, value) in additionalFields {
      body.append("--\(boundary)\r\n".data(using: .utf8)!)
      body.append("Content-Disposition: form-data; name=\"".data(using: .utf8)!)
      body.append(key.data(using: .utf8)!)
      body.append("\"\r\n\r\n".data(using: .utf8)!)
      body.append(value.data(using: .utf8)!)
      body.append("\r\n".data(using: .utf8)!)
    }

    // file field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"".data(using: .utf8)!)
    body.append(fieldName.data(using: .utf8)!)
    body.append("\"; filename=\"".data(using: .utf8)!)
    body.append(filename.data(using: .utf8)!)
    body.append("\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
    body.append(data)
    body.append("\r\n".data(using: .utf8)!)

    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    if let token = authProvider.accessToken {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    var (responseData, response) = try await URLSession.shared.upload(for: request, from: body)
    var httpResponse = response as? HTTPURLResponse

    if httpResponse?.statusCode == 401 {
      let refreshed = await authProvider.refreshAccessToken()
      guard refreshed, let newToken = authProvider.accessToken else {
        authProvider.removeAccessToken()
        throw APIClientError.unauthorized
      }
      var retryRequest = request
      retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
      (responseData, response) = try await URLSession.shared.upload(for: retryRequest, from: body)
      httpResponse = response as? HTTPURLResponse
    }

    guard let final = httpResponse else {
      throw APIClientError.serverError(statusCode: -1, message: "Invalid response")
    }
    return (responseData, final)
  }
}

enum APIClientError: Error, LocalizedError {
  case unauthorized
  case serverError(statusCode: Int, message: String?)
  case decodingError(message: String?)

  var errorDescription: String? {
    switch self {
    case .unauthorized:
      return "Unauthorized (401)"
    case .serverError(let statusCode, let message):
      return "Server error (\(statusCode)): \(message ?? "no message")"
    case .decodingError(let message):
      return "Decoding error: \(message ?? "no message")"
    }
  }
}

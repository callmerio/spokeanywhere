import Foundation

func remoteDictionaryResponse(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await URLSession.shared.data(for: request)
}

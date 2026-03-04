import Foundation

@MainActor
final class UDIDViewModel: ObservableObject {
    @Published var requestId: String?
    @Published var enrollURL: String?
    @Published var udidResult: UDIDResult?
    @Published var isLoading = false
    @Published var isPolling = false
    @Published var errorMessage: String?

    private let service = UDIDService()
    private var pollTask: Task<Void, Never>?

    func createRequest() async {
        isLoading = true
        errorMessage = nil
        udidResult = nil
        do {
            let id = try await service.createRequest()
            requestId = id
            enrollURL = service.enrollURL(requestId: id)
            startPolling()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startPolling() {
        guard let rid = requestId else { return }
        pollTask?.cancel()
        isPolling = true
        pollTask = Task {
            for _ in 0..<60 {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                do {
                    let result = try await service.result(requestId: rid)
                    if result.status == "received" {
                        udidResult = result
                        isPolling = false
                        return
                    }
                } catch {
                    // Keep polling
                }
            }
            isPolling = false
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        isPolling = false
    }

    func reset() {
        stopPolling()
        requestId = nil
        enrollURL = nil
        udidResult = nil
        errorMessage = nil
    }
}

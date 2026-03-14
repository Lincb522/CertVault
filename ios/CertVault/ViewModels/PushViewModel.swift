import Foundation

@MainActor
final class PushViewModel: ObservableObject {
    @Published var pushKeys: [PushKey] = []
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sendResult: String?
    @Published var isSending = false
    @Published var pushGuide: PushGuide?
    @Published var errorCodes: [APNsErrorCode] = []
    @Published var broadcastResult: BroadcastResult?
    @Published var isBroadcasting = false
    @Published var deviceCount: Int?

    @Published var pushSettings: PushSettings?
    @Published var pushStatus: PushStatus?
    @Published var devices: [PushDevice] = []
    @Published var deviceStats: PushDeviceStats?
    @Published var historyItems: [PushHistoryItem] = []
    @Published var historyStats: PushHistoryStats?
    @Published var historyTotal = 0
    @Published var historyPage = 1

    @Published var deviceHistory: [DeviceRegisterHistory] = []
    @Published var deviceHistoryTotal = 0
    @Published var deviceHistoryPage = 1
    @Published var deviceHistoryDetail: DeviceRegisterHistory?

    @Published var isValidating = false
    @Published var validateResult: DeviceValidateResult?
    @Published var isValidatingAll = false
    @Published var validateAllResult: DeviceValidateAllResult?

    @Published var testGroups: [BetaGroup] = []
    @Published var isLoadingTestGroups = false

    private let service = PushService()
    private let accountService = AccountService()
    private let appStoreService = AppStoreConnectService()
    private let certService = CertificateService()
    private let db = DatabaseManager.shared

    // MARK: - Push Keys

    func loadKeys() async {
        isLoading = true
        errorMessage = nil

        if let cached = try? db.fetchPushKeys(), !cached.isEmpty {
            pushKeys = cached
        }

        do {
            let fresh = try await service.listKeys()
            pushKeys = fresh
            try? db.savePushKeys(fresh)
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if pushKeys.isEmpty { errorMessage = error.localizedDescription }
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadAccounts() async {
        if let cached = try? db.fetchAccounts(), !cached.isEmpty {
            accounts = cached
        }
        do {
            let fresh = try await accountService.list()
            accounts = fresh
            try? db.saveAccounts(fresh)
        } catch is CancellationError { return }
        catch {
            if !Task.isCancelled, accounts.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    func loadTestGroups(accountId: String) async {
        guard !accountId.isEmpty else { return }
        isLoadingTestGroups = true
        do {
            testGroups = try await appStoreService.listGroups(accountId: accountId)
        } catch is CancellationError { return }
        catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isLoadingTestGroups = false }
    }

    func createKey(name: String, keyId: String, teamId: String, bundleIds: String, p8Content: String) async throws {
        try await service.createKey(name: name, keyId: keyId, teamId: teamId, bundleIds: bundleIds, p8Content: p8Content)
        await loadKeys()
    }

    func updateKey(id: String, name: String, keyId: String, teamId: String, bundleIds: String) async throws {
        try await service.updateKey(id: id, name: name, keyId: keyId, teamId: teamId, bundleIds: bundleIds)
        await loadKeys()
    }

    func deleteKey(id: String) async throws {
        try await service.deleteKey(id: id)
        pushKeys.removeAll { $0.id == id }
        try? db.deletePushKey(id: id)
    }

    // MARK: - Send / Broadcast

    func send(request: PushRequest) async {
        isSending = true
        sendResult = nil
        do {
            let result = try await service.send(request: request)
            if result.isSuccess {
                sendResult = "发送成功！APNs ID: \(result.apns_id ?? "N/A")"
            } else {
                let desc = result.reason_cn ?? result.reason ?? "未知错误"
                sendResult = "发送失败: \(desc)"
            }
        } catch let e as APIError {
            sendResult = "发送失败: \(e.localizedDescription)"
        } catch {
            sendResult = "发送失败: \(error.localizedDescription)"
        }
        isSending = false
    }

    func broadcast(request: BroadcastRequest) async {
        isBroadcasting = true
        broadcastResult = nil
        sendResult = nil
        do {
            let result = try await service.broadcast(request: request)
            broadcastResult = result
            var msg = "广播完成：\(result.success?.value ?? 0) 成功，\(result.failed?.value ?? 0) 失败"
            if let unreg = result.unregistered, unreg.value > 0 { msg += "，\(unreg.value) 已注销" }
            if let dur = result.duration { msg += " (\(dur.value)ms)" }
            sendResult = msg
            await loadDeviceCount()
        } catch {
            sendResult = "广播失败: \(error.localizedDescription)"
        }
        isBroadcasting = false
    }

    func loadDeviceCount() async {
        do {
            let stats = try await service.deviceStats()
            deviceCount = stats.total?.value
            deviceStats = stats
        } catch {
            do {
                let devices = try await service.registeredDevices()
                deviceCount = devices.count
            } catch {}
        }
    }

    // MARK: - Push Settings

    func loadSettings() async {
        do { pushSettings = try await service.getSettings() }
        catch { errorMessage = error.localizedDescription }
    }

    func saveSettings(_ updates: [String: String]) async throws {
        try await service.updateSettings(updates)
        await loadSettings()
    }

    func loadStatus() async {
        do { pushStatus = try await service.getStatus() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Device Management

    func loadDevices() async {
        isLoading = true
        do { devices = try await service.registeredDevices() }
        catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        if !Task.isCancelled { isLoading = false }
    }

    func loadDeviceStats() async {
        do { deviceStats = try await service.deviceStats() }
        catch {}
    }

    func deleteDevice(id: Int) async throws {
        try await service.deleteDevice(id: id)
        devices.removeAll { $0.id == id }
    }

    func batchDeleteDevices(ids: [Int]) async throws {
        try await service.batchDeleteDevices(ids: ids)
        devices.removeAll { ids.contains($0.id ?? -1) }
    }

    func batchUpdateDevices(ids: [Int], sandbox: Bool? = nil) async throws -> Int {
        let count = try await service.batchUpdateDevices(ids: ids, sandbox: sandbox)
        await loadDevices()
        return count
    }

    func addDevice(token: String, platform: String, sandbox: Bool, label: String?, remark: String? = nil) async throws {
        try await service.addDevice(token: token, platform: platform, sandbox: sandbox, label: label, remark: remark)
        await loadDevices()
    }

    func updateDevice(id: Int, label: String?, sandbox: Bool?, remark: String? = nil) async throws {
        try await service.updateDevice(id: id, label: label, sandbox: sandbox, remark: remark)
        await loadDevices()
    }

    func cleanupDevices(bundleId: String, pushKeyId: String?) async throws -> (valid: Int, removed: Int, errored: Int) {
        let result = try await service.cleanupDevices(bundleId: bundleId, pushKeyId: pushKeyId)
        await loadDevices()
        return result
    }

    // MARK: - Push History

    func loadHistory(page: Int = 1, type: String? = nil, status: String? = nil) async {
        isLoading = true
        do {
            let result = try await service.listHistory(page: page, type: type, status: status)
            if page == 1 {
                historyItems = result.items
            } else {
                historyItems.append(contentsOf: result.items)
            }
            historyTotal = result.total
            historyPage = page
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        if !Task.isCancelled { isLoading = false }
    }

    func loadHistoryStats() async {
        do { historyStats = try await service.historyStats() }
        catch {}
    }

    func deleteHistoryItem(id: Int) async throws {
        try await service.deleteHistoryItem(id: id)
        historyItems.removeAll { $0.id == id }
    }

    func clearHistory(beforeDays: Int? = nil) async throws {
        try await service.clearHistory(beforeDays: beforeDays)
        historyItems.removeAll()
        historyTotal = 0
        await loadHistoryStats()
    }

    func getHistoryDetail(id: Int) async throws -> PushHistoryItem {
        try await service.getHistoryItem(id: id)
    }

    @Published var isResending = false
    @Published var resendResult: String?

    func resendHistory(id: Int) async {
        isResending = true
        resendResult = nil
        do {
            let result = try await service.resendHistory(id: id)
            resendResult = result.message ?? "重发成功"
        } catch {
            resendResult = "重发失败: \(error.localizedDescription)"
        }
        isResending = false
    }

    // MARK: - Scheduled Pushes

    @Published var scheduledItems: [ScheduledPush] = []
    @Published var scheduledTotal = 0
    @Published var scheduledPage = 1

    func loadScheduled(page: Int = 1, status: String? = nil) async {
        isLoading = true
        do {
            let result = try await service.listScheduled(page: page, status: status)
            if page == 1 { scheduledItems = result.items }
            else { scheduledItems.append(contentsOf: result.items) }
            scheduledTotal = result.total
            scheduledPage = page
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        if !Task.isCancelled { isLoading = false }
    }

    func createScheduled(_ item: ScheduledPushCreate) async throws {
        try await service.createScheduled(item)
        await loadScheduled()
    }

    func cancelScheduled(id: Int) async throws {
        try await service.cancelScheduled(id: id)
        if let idx = scheduledItems.firstIndex(where: { $0.id == id }) {
            await loadScheduled()
        }
    }

    func deleteScheduled(id: Int) async throws {
        try await service.deleteScheduled(id: id)
        scheduledItems.removeAll { $0.id == id }
    }

    // MARK: - Guide & Error Codes

    @Published var guideLoaded = false

    func loadPushGuide() async {
        do { pushGuide = try await certService.pushGuide() }
        catch is CancellationError { return }
        catch {}
        if !Task.isCancelled { guideLoaded = true }
    }

    func loadErrorCodes() async {
        do { errorCodes = try await service.errorCodes() }
        catch is CancellationError { return }
        catch {}
    }

    // MARK: - Device Registration History

    func loadDeviceHistory(deviceToken: String? = nil, action: String? = nil, reset: Bool = true) async {
        if reset { deviceHistoryPage = 1 }
        isLoading = true
        do {
            let (items, total) = try await service.deviceHistory(
                deviceToken: deviceToken, action: action,
                limit: 30, offset: (deviceHistoryPage - 1) * 30
            )
            if reset { deviceHistory = items } else { deviceHistory.append(contentsOf: items) }
            deviceHistoryTotal = total
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadMoreDeviceHistory(deviceToken: String? = nil, action: String? = nil) async {
        guard deviceHistory.count < deviceHistoryTotal else { return }
        deviceHistoryPage += 1
        await loadDeviceHistory(deviceToken: deviceToken, action: action, reset: false)
    }

    func loadDeviceHistoryDetail(id: Int) async {
        isLoading = true
        do { deviceHistoryDetail = try await service.deviceHistoryDetail(id: id) }
        catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        if !Task.isCancelled { isLoading = false }
    }

    // MARK: - Device Validation

    func validateDevice(id: Int) async {
        isValidating = true
        validateResult = nil
        do { validateResult = try await service.validateDevice(id: id) }
        catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        if !Task.isCancelled { isValidating = false }
    }

    func validateAllDevices() async {
        isValidatingAll = true
        validateAllResult = nil
        do { validateAllResult = try await service.validateAllDevices() }
        catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        if !Task.isCancelled { isValidatingAll = false }
    }
}

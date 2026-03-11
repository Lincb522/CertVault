import Foundation

@MainActor
final class DeviceViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var selectedDevice: Device?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAccountId: String = ""
    @Published var accounts: [Account] = []

    @Published var isBinding = false
    @Published var bindSteps: [String] = []
    @Published var bindResult: AutoBindResult?
    @Published var bindError: String?

    private let service = DeviceService()
    private let accountService = AccountService()
    private let db = DatabaseManager.shared

    func loadAccounts() async {
        AppLogger.data.info("📱 Loading accounts for devices...")

        if let cached = try? db.fetchAccounts(), !cached.isEmpty {
            accounts = cached
            if selectedAccountId.isEmpty, let first = cached.first {
                selectedAccountId = first.id
            }
        }

        do {
            let fresh = try await accountService.list()
            accounts = fresh
            try? db.saveAccounts(fresh)
            if selectedAccountId.isEmpty, let first = fresh.first {
                selectedAccountId = first.id
            }
            await loadDevices()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("📱 Load accounts failed | \(error.localizedDescription)")
            }
            if !selectedAccountId.isEmpty { await loadDevices() }
        }
    }

    func loadDevices() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("📱 Loading devices for account=\(self.selectedAccountId)")
        isLoading = true
        errorMessage = nil

        if let cached = try? db.fetchDevices(accountId: selectedAccountId), !cached.isEmpty {
            devices = cached
        }

        do {
            let fresh = try await service.list(accountId: selectedAccountId)
            devices = fresh
            try? db.saveDevices(fresh, accountId: selectedAccountId)
            WidgetHelper.reloadAll()
            AppLogger.data.info("📱 Loaded \(self.devices.count) devices")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if devices.isEmpty { errorMessage = error.localizedDescription }
                AppLogger.data.error("📱 Load devices failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled {
            isLoading = false
        }
    }

    func loadDetail(deviceId: String) async {
        AppLogger.data.info("📱 Loading device detail id=\(deviceId)")
        isLoading = true
        errorMessage = nil
        do {
            selectedDevice = try await service.detail(deviceId: deviceId)
            AppLogger.data.info("📱 Device detail loaded: \(self.selectedDevice?.name ?? "?")")
        } catch is CancellationError {
            AppLogger.data.info("📱 Device detail request cancelled (view disappeared)")
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("📱 Device detail failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled {
            isLoading = false
        }
    }

    func register(name: String, udid: String, platform: String = "IOS") async throws {
        AppLogger.data.info("📱 Registering device: \(name) udid=\(udid)")
        let _ = try await service.register(accountId: selectedAccountId, name: name, udid: udid, platform: platform)
        AppLogger.data.info("📱 Device registered: \(name)")
        await loadDevices()
    }

    func batchRegister(text: String) async throws {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var devicesArr: [[String: String]] = []
        for line in lines {
            let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                devicesArr.append(["udid": parts[0], "name": parts[1], "platform": "IOS"])
            } else if parts.count == 1 {
                devicesArr.append(["udid": parts[0], "name": "Device", "platform": "IOS"])
            }
        }
        guard !devicesArr.isEmpty else { throw APIError.serverError("没有有效的设备数据") }
        AppLogger.data.info("📱 Batch registering \(devicesArr.count) devices")
        try await service.batchRegister(accountId: selectedAccountId, devices: devicesArr)
        AppLogger.data.info("📱 Batch register complete")
        await loadDevices()
    }

    func toggleDeviceStatus(deviceId: String, enable: Bool) async throws {
        AppLogger.data.info("📱 \(enable ? "Enabling" : "Disabling") device id=\(deviceId)")
        let updated = try await service.setStatus(deviceId: deviceId, enabled: enable)
        if let idx = devices.firstIndex(where: { $0.id == deviceId }) {
            devices[idx] = updated
        }
        if selectedDevice?.id == deviceId {
            selectedDevice = updated
        }
        AppLogger.data.info("📱 Device status changed to \(updated.status ?? "?")")
    }

    func deleteDevice(deviceId: String, keepApple: Bool = false) async throws {
        AppLogger.data.info("📱 Deleting device id=\(deviceId) keepApple=\(keepApple)")
        try await service.delete(deviceId: deviceId, keepApple: keepApple)
        AppLogger.data.info("📱 Device deleted")
        await loadDevices()
    }

    func autoBind(
        name: String, udid: String, bundleId: String, bundleName: String,
        certType: String = "IOS_DEVELOPMENT", profileType: String = "IOS_APP_DEVELOPMENT",
        platform: String = "IOS",
        password: String = "123456"
    ) async {
        AppLogger.data.info("📱 Auto-bind start | device=\(name) udid=\(udid) bundle=\(bundleId)")
        isBinding = true
        bindSteps = []
        bindResult = nil
        bindError = nil

        let request = AutoBindRequest(
            account_id: selectedAccountId,
            name: name, udid: udid, platform: platform,
            bundle_identifier: bundleId, bundle_name: bundleName,
            cert_type: certType, profile_type: profileType,
            password: password
        )

        do {
            let result = try await service.autoBind(request: request)
            bindSteps = (result.steps ?? []).compactMap { $0.message }
            bindResult = result
            AppLogger.data.info("📱 Auto-bind success | steps=\(result.steps?.count ?? 0)")
            if let dev = result.device { try? db.saveDevices([dev], accountId: selectedAccountId) }
            if let bid = result.bundle_id { try? db.saveBundleIds([bid], accountId: selectedAccountId) }
            await loadDevices()
        } catch {
            bindError = error.localizedDescription
            AppLogger.data.error("📱 Auto-bind failed | \(error.localizedDescription)")
        }
        isBinding = false
    }
}

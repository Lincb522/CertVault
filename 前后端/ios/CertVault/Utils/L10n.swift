import Foundation

private func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

// MARK: - Localized enum (status / type translations)

enum Localized {
    static func status(_ raw: String) -> String {
        let key = "status.\(raw.lowercased())"
        let result = NSLocalizedString(key, comment: "")
        return result == key ? raw : result
    }

    static func certType(_ raw: String) -> String {
        let key = "certType.\(raw)"
        let result = NSLocalizedString(key, comment: "")
        return result == key ? raw : result
    }

    static func profileType(_ raw: String) -> String {
        let key = "profileType.\(raw)"
        let result = NSLocalizedString(key, comment: "")
        return result == key ? raw : result
    }

    static func platform(_ raw: String) -> String {
        let key = "platform.\(raw.uppercased())"
        let result = NSLocalizedString(key, comment: "")
        return result == key ? raw : result
    }

    static func deviceClass(_ raw: String) -> String {
        let key = "deviceClass.\(raw.uppercased())"
        let result = NSLocalizedString(key, comment: "")
        return result == key ? raw : result
    }
}

// MARK: - Type-safe localization constants

enum L10n {
    // MARK: Common
    static let cancel = L("common.cancel")
    static let confirm = L("common.confirm")
    static let delete = L("common.delete")
    static let save = L("common.save")
    static let create = L("common.create")
    static let edit = L("common.edit")
    static let `import` = L("common.import")
    static let upload = L("common.upload")
    static let download = L("common.download")
    static let ok = L("common.ok")
    static let retry = L("common.retry")
    static let close = L("common.close")
    static let done = L("common.done")
    static let loading = L("common.loading")
    static let error = L("common.error")
    static let success = L("common.success")
    static let account = L("common.account")
    static let select = L("common.select")
    static let selectAll = L("common.selectAll")
    static let na = L("common.na")
    static let unknown = L("common.unknown")
    static let unnamed = L("common.unnamed")
    static func count(_ n: Int) -> String { L("common.count", n) }
    static func unitDevice(_ n: Int) -> String { L("common.unitDevice", n) }

    // MARK: Tab
    enum Tab {
        static let dashboard = L("tab.dashboard")
        static let accounts = L("tab.accounts")
        static let devices = L("tab.devices")
        static let certificates = L("tab.certificates")
        static let more = L("tab.more")
    }

    // MARK: Dashboard
    enum Dashboard {
        static let title = L("dashboard.title")
        static let greetingMorning = L("dashboard.greeting.morning")
        static let greetingNoon = L("dashboard.greeting.noon")
        static let greetingAfternoon = L("dashboard.greeting.afternoon")
        static let greetingEvening = L("dashboard.greeting.evening")
        static let statAccounts = L("dashboard.stat.accounts")
        static let statDevices = L("dashboard.stat.devices")
        static let statCerts = L("dashboard.stat.certificates")
        static let statProfiles = L("dashboard.stat.profiles")
        static let quickActions = L("dashboard.quickActions")
        static let actionCreateCert = L("dashboard.action.createCert")
        static let actionAddDevice = L("dashboard.action.addDevice")
        static let actionProfiles = L("dashboard.action.profiles")
        static let actionAccounts = L("dashboard.action.accounts")
        static let recentCerts = L("dashboard.recentCerts")
        static let recentDevices = L("dashboard.recentDevices")
        static let noCerts = L("dashboard.noCerts")
        static let noDevices = L("dashboard.noDevices")
    }

    // MARK: Account
    enum Account {
        static let title = L("account.title")
        static let detail = L("account.detail")
        static let add = L("account.add")
        static let edit = L("account.edit")
        static let manualAdd = L("account.manualAdd")
        static let quickImport = L("account.quickImport")
        static let uploadP8 = L("account.uploadP8")
        static let testConnection = L("account.testConnection")
        static let downloadP8 = L("account.downloadP8")
        static let synced = L("account.synced")
        static let emptyTitle = L("account.empty.title")
        static let emptyMessage = L("account.empty.message")
        static let deleteTitle = L("account.delete.title")
        static let deleteMessage = L("account.delete.message")
        static let formName = L("account.form.name")
        static let formIssuerId = L("account.form.issuerId")
        static let formKeyId = L("account.form.keyId")
        static let formSectionBasic = L("account.form.section.basic")
        static let formP8Content = L("account.form.p8Content")
        static let formP8Hint = L("account.form.p8Hint")
        static let importTitle = L("account.import.title")
        static let uploadTitle = L("account.upload.title")
        static let selectP8 = L("account.selectP8")
    }

    // MARK: Device
    enum Device {
        static let title = L("device.title")
        static let detail = L("device.detail")
        static let register = L("device.register")
        static let batchImport = L("device.batchImport")
        static let autoBind = L("device.autoBind")
        static let rebind = L("device.rebind")
        static let deleteDevice = L("device.delete")
        static let deleteTitle = L("device.deleteConfirm.title")
        static let deleteMessage = L("device.deleteConfirm.message")
        static let enableDevice = L("device.enable")
        static let disableDevice = L("device.disable")
        static let disableTitle = L("device.disableConfirm.title")
        static let disableMessage = L("device.disableConfirm.message")
        static let enabledSection = L("device.section.enabled")
        static let disabledSection = L("device.section.disabled")
        static let ineligibleSection = L("device.section.ineligible")
        static let emptyTitle = L("device.empty.title")
        static let emptyMessage = L("device.empty.message")
        static let emptyAction = L("device.empty.action")
        static let noAccountTitle = L("device.noAccount.title")
        static let noAccountMessage = L("device.noAccount.message")
        static let search = L("device.search")
        static let formName = L("device.form.name")
        static let formUdid = L("device.form.udid")
        static let formPlatform = L("device.form.platform")
        static let relatedCerts = L("device.relatedCerts")
        static let relatedProfiles = L("device.relatedProfiles")
        static let noRelatedCerts = L("device.noRelatedCerts")
        static let noRelatedProfiles = L("device.noRelatedProfiles")
        static let batchDownload = L("device.batchDownload")
        static let batchDownloadDesc = L("device.batchDownload.desc")
        static let noBatchProfiles = L("device.noBatchProfiles")
    }

    // MARK: Certificate
    enum Cert {
        static let title = L("cert.title")
        static let detail = L("cert.detail")
        static let create = L("cert.create")
        static let selfSign = L("cert.selfSign")
        static let generateCA = L("cert.generateCA")
        static let search = L("cert.search")
        static let downloadP12 = L("cert.downloadP12")
        static let downloadCER = L("cert.downloadCER")
        static let password = L("cert.password")
        static let type = L("cert.type")
        static let serial = L("cert.serial")
        static let expiresAt = L("cert.expiresAt")
        static let createdAt = L("cert.createdAt")
        static let platform = L("cert.platform")
        static let typeLabel = L("cert.type_label")
        static let emptyTitle = L("cert.empty.title")
        static let emptyMessage = L("cert.empty.message")
        static let noAccountTitle = L("cert.noAccount.title")
        static let noAccountMessage = L("cert.noAccount.message")
        static let deleteTitle = L("cert.delete.title")
        static let deleteMessage = L("cert.delete.message")
        static let quotaTitle = L("cert.quota.title")
        static let quotaUsed = L("cert.quota.used")
        static let quotaFull = L("cert.quota.full")
    }

    // MARK: Profile
    enum Profile {
        static let title = L("profile.title")
        static let detail = L("profile.detail")
        static let create = L("profile.create")
        static let download = L("profile.download")
        static let deleteProfile = L("profile.delete")
        static let downloadable = L("profile.downloadable")
        static let bundleId = L("profile.bundleId")
        static let relatedCerts = L("profile.relatedCerts")
        static let boundDevices = L("profile.boundDevices")
        static let noDevices = L("profile.noDevices")
        static let emptyTitle = L("profile.empty.title")
        static let emptyMessage = L("profile.empty.message")
        static let noAccountTitle = L("profile.noAccount.title")
        static let noAccountMessage = L("profile.noAccount.message")
        static let deleteTitle = L("profile.delete.title")
        static let deleteMessage = L("profile.delete.message")
        static let noBundleId = L("profile.noBundleId")
    }

    // MARK: BundleID
    enum BundleID {
        static let title = L("bundleId.title")
        static let detail = L("bundleId.detail")
        static let create = L("bundleId.create")
        static let identifier = L("bundleId.identifier")
        static let identifierHint = L("bundleId.identifierHint")
        static let deleteBundle = L("bundleId.delete")
        static let deleteTitle = L("bundleId.delete.title")
        static let deleteMessage = L("bundleId.delete.message")
        static let emptyTitle = L("bundleId.empty.title")
        static let emptyMessage = L("bundleId.empty.message")
        static let relatedDevices = L("bundleId.relatedDevices")
        static let relatedCerts = L("bundleId.relatedCerts")
        static let relatedProfiles = L("bundleId.relatedProfiles")
        static let noDevices = L("bundleId.noDevices")
        static let noCerts = L("bundleId.noCerts")
        static let noProfiles = L("bundleId.noProfiles")
        static let enabledCaps = L("bundleId.enabledCaps")
        static let noCaps = L("bundleId.noCaps")
    }

    // MARK: Settings
    enum Settings {
        static let title = L("settings.title")
        static let userManagement = L("settings.userManagement")
        static let emailConfig = L("settings.emailConfig")
        static let displayMode = L("settings.displayMode")
        static let changePassword = L("settings.changePassword")
        static let cache = L("settings.cache")
        static let clearCache = L("settings.clearCache")
        static let clearCacheTitle = L("settings.clearCache.title")
        static let clearCacheMessage = L("settings.clearCache.message")
        static let clearCacheDone = L("settings.clearCache.done")
        static let notification = L("settings.notification")
        static let serverStatus = L("settings.serverStatus")
        static let version = L("settings.version")
        static let logout = L("settings.logout")
        static let logoutTitle = L("settings.logout.title")
        static let logoutMessage = L("settings.logout.message")
    }

    // MARK: Login
    enum Login {
        static let title = L("login.title")
        static let subtitle = L("login.subtitle")
        static let username = L("login.username")
        static let password = L("login.password")
        static let submit = L("login.submit")
        static let noAccount = L("login.noAccount")
        static let goRegister = L("login.goRegister")
    }

    // MARK: Register
    enum Register {
        static let title = L("register.title")
        static let subtitle = L("register.subtitle")
        static let username = L("register.username")
        static let usernameHint = L("register.usernameHint")
        static let email = L("register.email")
        static let emailHint = L("register.emailHint")
        static let password = L("register.password")
        static let passwordHint = L("register.passwordHint")
        static let confirmPassword = L("register.confirmPassword")
        static let confirmPasswordHint = L("register.confirmPasswordHint")
        static let verifyCode = L("register.verifyCode")
        static let getCode = L("register.getCode")
        static func codeCooldown(_ s: Int) -> String { L("register.codeCooldown", s) }
        static let submit = L("register.submit")
        static let hasAccount = L("register.hasAccount")
        static let goLogin = L("register.goLogin")
        static let passwordMismatch = L("register.passwordMismatch")
    }

    // MARK: More
    enum More {
        static let title = L("more.title")
        static let sectionResources = L("more.section.resources")
        static let sectionPush = L("more.section.push")
        static let sectionTools = L("more.section.tools")
    }

    // MARK: HealthCheck
    enum HealthCheck {
        static let title = L("health.title")
        static let localCheck = L("health.localCheck")
        static let remoteCheck = L("health.remoteCheck")
        static let addAccount = L("health.addAccount")
        static let startCheck = L("health.startCheck")
        static let summary = L("health.summary")
        static let issues = L("health.issues")
        static let certStatus = L("health.certStatus")
        static let profileStatus = L("health.profileStatus")
    }

    // MARK: UDID
    enum UDID {
        static let title = L("udid.title")
        static let heading = L("udid.heading")
        static let desc = L("udid.desc")
        static let scanQR = L("udid.scanQR")
        static let orVisit = L("udid.orVisit")
        static let copyLink = L("udid.copyLink")
        static let waiting = L("udid.waiting")
        static let regenerate = L("udid.regenerate")
        static let success = L("udid.success")
        static let copyAll = L("udid.copyAll")
        static let retry = L("udid.retry")
    }

    // MARK: AutoBind
    enum AutoBind {
        static let title = L("autoBind.title")
        static let desc = L("autoBind.desc")
        static let start = L("autoBind.start")
        static let willCreate = L("autoBind.willCreate")
        static let typeCert = L("autoBind.typeCert")
        static let running = L("autoBind.running")
        static let success = L("autoBind.success")
        static let successDesc = L("autoBind.success.desc")
        static let failed = L("autoBind.failed")
    }

    // MARK: BatchImport
    enum BatchImport {
        static let title = L("batchImport.title")
        static let section = L("batchImport.section")
        static let hint = L("batchImport.hint")
        static let successTitle = L("batchImport.success.title")
        static let successMessage = L("batchImport.success.message")
    }

    // MARK: Push
    enum Push {
        static let keysTitle = L("push.keys.title")
        static let keysEmptyTitle = L("push.keys.empty.title")
        static let keysEmptyMessage = L("push.keys.empty.message")
        static let keysImport = L("push.keys.import")
        static let keysEdit = L("push.keys.edit")
        static let keysDownloadP8 = L("push.keys.downloadP8")
        static let keysDeleteTitle = L("push.keys.delete.title")
        static let keysSelectP8 = L("push.keys.selectP8")
        static let testTitle = L("push.test.title")
        static let testKeyTab = L("push.test.keyTab")
        static let testAccountTab = L("push.test.accountTab")
        static let testManualTab = L("push.test.manualTab")
        static let testSend = L("push.test.send")
        static let testAutoFill = L("push.test.autoFill")
        static let guideTitle = L("push.guide.title")
        static let guideMethods = L("push.guide.methods")
        static let guideServices = L("push.guide.services")
        static let guideErrors = L("push.guide.errors")
        static let guidePros = L("push.guide.pros")
        static let guideCons = L("push.guide.cons")
        static let guideSteps = L("push.guide.steps")
        static let guideEmptyMethods = L("push.guide.emptyMethods")
        static let guideEmptyServices = L("push.guide.emptyServices")
        static let guideEmptyErrors = L("push.guide.emptyErrors")
        static let tokenTitle = L("push.token.title")
        static let tokenDesc = L("push.token.desc")
        static let tokenNotes = L("push.token.notes")
    }

    // MARK: UserManagement
    enum UserMgmt {
        static let title = L("user.title")
        static let emptyTitle = L("user.empty.title")
        static let emptyMessage = L("user.empty.message")
        static let roleSuper = L("user.role.superadmin")
        static let roleUser = L("user.role.user")
        static let resetPassword = L("user.resetPassword")
        static let resetPasswordTitle = L("user.resetPassword.title")
        static let deleteUser = L("user.deleteUser")
        static let deleteTitle = L("user.delete.title")
        static func deleteMessage(_ name: String) -> String { L("user.delete.message", name) }
        static let resultTitle = L("user.result.title")
    }

    // MARK: Capability
    enum Capability {
        static let title = L("capability.title")
        static let disableAll = L("capability.disableAll")
        static let disableAllTitle = L("capability.disableAll.title")
        static let disableAllMessage = L("capability.disableAll.message")
        static let enabled = L("capability.enabled")
        static let failedTitle = L("capability.failed.title")
    }
}

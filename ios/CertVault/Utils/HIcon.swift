import SwiftUI
import HiconIcons

struct HIcon: View {
    let image: UIImage

    init(_ image: UIImage) {
        self.image = image
    }

    var body: some View {
        Image(uiImage: image)
            .renderingMode(.template)
    }
}

extension Image {
    init(hicon: UIImage) {
        self.init(uiImage: hicon)
    }
}

enum AppIcon {
    static let dashboard = Hicon.chart
    static let account = Hicon.password1
    static let device = Hicon.display3
    static let certificate = Hicon.verified
    static let more = Hicon.moreCircle
    static let profile = Hicon.documentAlignLeft1
    static let bundleID = Hicon.bag1
    static let capability = Hicon.tickSquare
    static let pushKey = Hicon.notification1
    static let pushTest = Hicon.send1
    static let udid = Hicon.scan1
    static let health = Hicon.heart1
    static let settings = Hicon.setting
    static let shield = Hicon.shieldTick
    static let user = Hicon.profile1
    static let lock = Hicon.lock1
    static let server = Hicon.website
    static let add = Hicon.add
    static let addCircle = Hicon.addCircle
    static let addSquare = Hicon.addSquare
    static let delete = Hicon.delete1
    static let download = Hicon.download
    static let docDownload = Hicon.documentDownload1
    static let copy = Hicon.documentAdd2
    static let edit = Hicon.edit1
    static let refresh = Hicon.refresh1
    static let close = Hicon.closeCircle
    static let check = Hicon.tickCircle
    static let warning = Hicon.dangerTriangle
    static let info = Hicon.informationCircle
    static let wifi = Hicon.wifi
    static let pen = Hicon.pen
    static let logout = Hicon.logout
    static let link = Hicon.link
    static let star = Hicon.star1
    static let group = Hicon.group1
    static let game = Hicon.ps51
    static let work = Hicon.work
    static let category = Hicon.category
    static let profileCircle = Hicon.profileCircle
    static let watch = Hicon.watch1
    static let tv = Hicon.tv
    static let display = Hicon.display1
    static let docAdd = Hicon.documentAdd1
    static let docUpload = Hicon.documentUpload1
    static let email = Hicon.sms1
    static let code = Hicon.message1
    static let chevronRight = Hicon.right2
    static let moon = Hicon.moon
    static let sun = Hicon.sun1
    static let tick = Hicon.tick
}

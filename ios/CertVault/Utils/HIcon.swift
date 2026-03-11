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
    static let clock = Hicon.timeCircle1
    static let trash = Hicon.delete1
    static let search = Hicon.search1
    static let filter = Hicon.filter1
    static let send = Hicon.send1
    static let phone = Hicon.call
    static let globe = Hicon.website
    static let hammer = Hicon.work
    static let person = Hicon.profile1
    static let personAdd = Hicon.profileAdd1
    static let personGroup = Hicon.group1
    static let megaphone = Hicon.notification2
    static let tag = Hicon.tag
    static let gear = Hicon.setting
    static let checklist = Hicon.tickSquare
    static let paperplane = Hicon.send2
    static let pause = Hicon.pauseCircle
    static let play = Hicon.playCircle
    static let stop = Hicon.stopCircle
    static let doc = Hicon.documentAlignLeft1
    static let docText = Hicon.documentAlignLeft2
    static let docCopy = Hicon.documentAdd2
    static let folder = Hicon.folder1
    static let folderAdd = Hicon.folderAdd1
    static let speaker = Hicon.speaker1
    static let speakerSlash = Hicon.volumeSlash
    static let bell = Hicon.notification1
    static let eye = Hicon.show
    static let eyeSlash = Hicon.hide
    static let pencil = Hicon.edit1
    static let plus = Hicon.add
    static let plusCircle = Hicon.addCircle
    static let minus = Hicon.minus
    static let minusCircle = Hicon.minusCircle
    static let share = Hicon.upload
    static let iphone = Hicon.display3
    static let iphoneSlash = Hicon.display4
    static let arrowUp = Hicon.up1
    static let arrowDown = Hicon.down1
    static let arrowRight = Hicon.right1
    static let arrowLeft = Hicon.left1
    static let location = Hicon.location
    static let heart = Hicon.heart1
    static let bookmark = Hicon.bookmark1
    static let pin = Hicon.pin
    static let key = Hicon.password1
    static let image = Hicon.image
    static let microphone = Hicon.microphone1
    static let music = Hicon.music
    static let video = Hicon.video1
    static let message = Hicon.message2
    static let zoomIn = Hicon.zoomIn
    static let zoomOut = Hicon.zoomOut
    static let swap = Hicon.swap1
    static let chart = Hicon.chart
    static let up = Hicon.up1
    static let down = Hicon.down1
    static let moreCircle = Hicon.moreCircle
    static let sparkle = Hicon.star2
    static let bellSlash = Hicon.notification3
    static let arrowClockwise = Hicon.refresh1
    static let xmark = Hicon.close
}

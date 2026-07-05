import XCTest
@testable import CastBridge

final class UPnPModelTests: XCTestCase {
    func testMediaItemDetectsVideoByMimeType() {
        let item = MediaItem(
            id: "1",
            title: "Film",
            isContainer: false,
            parentID: "0",
            mediaClass: nil,
            streamURL: URL(string: "http://192.168.1.10/video.bin"),
            mimeType: "video/mp4",
            duration: 120,
            size: 1_000_000,
            thumbnailURL: nil
        )

        XCTAssertTrue(item.isVideo)
        XCTAssertEqual(item.formattedDuration, "2:00")
    }

    func testMediaItemDetectsFolder() {
        let folder = MediaItem(
            id: "folder",
            title: "Films",
            isContainer: true,
            parentID: "0",
            mediaClass: "object.container",
            streamURL: nil,
            mimeType: nil,
            duration: nil,
            size: nil,
            thumbnailURL: nil
        )

        XCTAssertFalse(folder.isVideo)
    }
}

final class UPnPDeviceParserTests: XCTestCase {
    func testResolveRelativeControlURL() {
        let base = URL(string: "http://192.168.1.10:8200/rootDesc.xml")!
        let resolved = UPnPDeviceParser.resolveURL("/MediaServer/ContentDirectory/ctrl", base: base)
        XCTAssertEqual(resolved?.absoluteString, "http://192.168.1.10:8200/MediaServer/ContentDirectory/ctrl")
    }
}

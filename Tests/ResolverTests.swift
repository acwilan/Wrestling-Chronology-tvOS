import XCTest
import Foundation
@testable import WrestlingChronology_tvOS

final class ResolverTests: XCTestCase {
    func testArchiveResolverRejectsForeignHost() async {
        let source = EpisodeSource(type: "archive", url: "https://evil.example/download/test.mp4", urls: nil, videoId: nil, videoIds: nil, channelId: nil, owner: nil, title: nil, label: nil, filename: nil, programme: nil, duration: nil, bytes: nil, height: nil, language: nil, audioLanguage: nil, creator: nil)
        do {
            _ = try await SourceResolver().resolve(source)
            XCTFail("foreign host should be rejected")
        } catch let error as PlaybackError {
            XCTAssertEqual(error, .invalidSource(source.sourceKey))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDailymotionParserValidatesOwnerAndHLS() throws {
        let data = Data(#"{"owner":{"username":"approved"},"qualities":{"auto":[{"type":"application/x-mpegURL","url":"https://cdn.example/stream.m3u8"}]}}"#.utf8)
        let result = try DailymotionMetadataParser().parse(data: data, expectedOwner: "approved")
        XCTAssertEqual(result.owner, "approved")
        XCTAssertEqual(result.hlsURL.absoluteString, "https://cdn.example/stream.m3u8")
    }

    func testOKRUValidatorAcceptsOnlyKnownMediaHostFamilies() {
        XCTAssertTrue(OKRUHostValidator.isMediaURL("https://video.okcdn.ru/file"))
        XCTAssertTrue(OKRUHostValidator.isMediaURL("https://video.vkuser.net/file"))
        XCTAssertFalse(OKRUHostValidator.isMediaURL("https://okcdn.ru.evil.example/file"))
        XCTAssertFalse(OKRUHostValidator.isMediaURL("http://video.okcdn.ru/file"))
    }
}

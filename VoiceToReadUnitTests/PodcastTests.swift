import XCTest
import AVFoundation
@testable import VoiceToRead

@MainActor
final class PodcastTests: XCTestCase {
    func testPilotResourcesHaveOrderedBilingualTextAndRealWordCues() throws {
        let episodes = try PodcastEpisode.load()
        XCTAssertEqual(episodes.count, 1)
        let episode = try XCTUnwrap(episodes.first)
        XCTAssertEqual(episode.id, "POD-B1B2-001")
        XCTAssertEqual(episode.segments.count, 30)
        XCTAssertTrue((480...720).contains(episode.normalDuration))
        XCTAssertTrue((480...720).contains(episode.duration))
        for segment in episode.segments {
            let url = try episode.resourceURL(number: segment.number, fileExtension: "json")
            let timing = try JSONDecoder().decode(GuidedWordTiming.self, from: Data(contentsOf: url))
            XCTAssertNoThrow(try timing.validate(expected: segment.en))
            let audio = try AVAudioPlayer(contentsOf: episode.resourceURL(number: segment.number, fileExtension: "mp3"))
            XCTAssertEqual(audio.duration, segment.duration, accuracy: 0.25)
            XCTAssertLessThanOrEqual(timing.words.map(\.end).max() ?? 0, audio.duration + 0.25)
            XCTAssertFalse(segment.es.isEmpty)
        }
    }
    func testContinuousPlaybackPausePaceAndStopRejectStaleCompletion() throws {
        let episode = try XCTUnwrap(PodcastEpisode.load().first)
        var outputs: [FakePodcastOutput] = []
        var activations = 0, deactivations = 0
        let player = PodcastPlayback(episode: episode, makeOutput: { _ in
            let output = FakePodcastOutput(); outputs.append(output); return output
        }, activate: { activations += 1 }, deactivate: { deactivations += 1 })
        player.play()
        XCTAssertEqual(player.state, .playing)
        XCTAssertEqual(outputs.count, 1)
        let stale = outputs[0].onFinish
        outputs[0].onFinish?(true)
        XCTAssertEqual(player.index, 1)
        XCTAssertEqual(outputs.count, 2)
        XCTAssertEqual(activations, 1, "Adjacent fragments retain the output session")
        stale?(true)
        XCTAssertEqual(player.index, 1)
        outputs[1].currentTime = 3
        player.pause()
        XCTAssertEqual(player.state, .paused)
        XCTAssertEqual(player.position, 3)
        XCTAssertEqual(deactivations, 1)
        player.slow = false
        XCTAssertEqual(outputs[1].rate, Float(1 / episode.baseSpeed), accuracy: 0.001)
        player.play()
        XCTAssertEqual(outputs.count, 2, "Resume retains the same audio and position")
        XCTAssertEqual(player.position, 3)
        let oldCompletion = outputs[1].onFinish
        player.stop()
        oldCompletion?(true)
        XCTAssertEqual(player.state, .idle)
        XCTAssertEqual(player.index, 0)
        XCTAssertEqual(player.progress, 0)
        XCTAssertNil(player.range)
        XCTAssertEqual(activations, deactivations)
        player.close()
    }
    func testSelectingPausedFragmentDoesNotStartAudioAndCompletionCanRestart() throws {
        let episode = try XCTUnwrap(PodcastEpisode.load().first)
        var outputs: [FakePodcastOutput] = []
        let player = PodcastPlayback(episode: episode, makeOutput: { _ in
            let output = FakePodcastOutput(); outputs.append(output); return output
        }, activate: {}, deactivate: {})
        player.select(2)
        XCTAssertEqual(outputs.count, 0)
        XCTAssertEqual(player.index, 2)
        player.startSegment(episode.segments.count - 1)
        outputs.last?.onFinish?(true)
        XCTAssertTrue(player.completed)
        XCTAssertEqual(player.progress, 1, accuracy: 0.001)
        player.play()
        XCTAssertEqual(player.index, 0)
        XCTAssertFalse(player.completed)
        player.close()
    }
    func testMissingAudioFailsWithoutStartingAnotherWorkflow() throws {
        let episode = try XCTUnwrap(PodcastEpisode.load().first)
        let player = PodcastPlayback(episode: episode, makeOutput: { _ in throw PodcastEpisode.Failure.invalidContent },
                                    activate: {}, deactivate: {})
        player.play()
        XCTAssertEqual(player.state, .idle)
        XCTAssertNotNil(player.message)
        XCTAssertNil(player.range)
        player.close()
    }
    func testInvalidEpisodeCannotResolveResources() throws {
        let episode = try XCTUnwrap(PodcastEpisode.load().first)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(episode)) as? [String: Any])
        json["id"] = "../outside"
        let invalid = try JSONDecoder().decode(PodcastEpisode.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try invalid.validate())
        XCTAssertThrowsError(try invalid.resourceURL(number: 1, fileExtension: "mp3"))
        XCTAssertThrowsError(try episode.resourceURL(number: -1, fileExtension: "mp3"))
    }
}

@MainActor
private final class FakePodcastOutput: PodcastAudioOutput {
    var currentTime: TimeInterval = 0
    var rate: Float = 1
    var onFinish: ((Bool) -> Void)?
    func play() -> Bool { true }
    func pause() { }
    func stop() { }
}

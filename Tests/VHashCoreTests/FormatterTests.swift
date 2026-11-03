import Foundation
import Testing
@testable import VHashCore

@Suite("Formatters")
struct FormatterTests {
    let ok = FileResult(path: "/v/a.mp4", phash: "aa", oshash: "bb", duration: 65.4)
    let bad = FileResult(path: "/v/b, \"x\".mp4", error: "line1\nline2")

    @Test("CSV escapes commas, quotes and newlines and has a header")
    func csv() {
        let lines = Formatters.csv([ok, bad])
        #expect(lines == """
            path,phash,oshash,duration,status,error
            /v/a.mp4,aa,bb,65.400,ok,
            "/v/b, ""x"".mp4",,,,error,"line1
            line2"

            """)
    }

    @Test("csvField leaves plain text alone")
    func csvPlain() {
        #expect(Formatters.csvField("plain") == "plain")
        #expect(Formatters.csvField("a,b") == "\"a,b\"")
    }

    @Test("JSON is an array with all keys, null error on success, sorted and pretty")
    func json() throws {
        let text = try Formatters.json([ok, bad])
        let array = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]])
        #expect(array.count == 2)
        #expect(Set(array[0].keys) == ["path", "phash", "oshash", "duration", "error"])
        #expect(array[0]["error"] is NSNull)
        #expect(array[0]["phash"] as? String == "aa")
        #expect(array[1]["error"] as? String == "line1\nline2")
        #expect(array[1]["phash"] is NSNull)
        #expect(text.contains("\n  {"))
        let keys = ["duration", "error", "oshash", "path", "phash"].compactMap { text.range(of: "\"\($0)\"")?.lowerBound }
        #expect(keys == keys.sorted())
        #expect(!text.contains("\\/"))
    }

    @Test("JSON for no results is an empty array")
    func jsonEmpty() throws {
        #expect(try Formatters.json([]) == "[\n\n]\n" || Formatters.json([]) == "[]\n")
    }

    @Test("table shows only requested hash columns and aligns them")
    func table() {
        let text = Formatters.table([ok, FileResult(path: "/v/long-name.mp4", oshash: "cc", duration: 3700)], algorithms: [.oshash])
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines[0].hasPrefix("PATH"))
        #expect(!text.contains("PHASH"))
        #expect(lines[0].contains("OSHASH"))
        #expect(lines[2].contains("1:01:40"))
        #expect(lines[1].contains("0:01:05"))
        // OSHASH column starts at the same offset on every row.
        let offsets = lines.map { $0.range(of: #"OSHASH|bb|cc"#, options: .regularExpression)!.lowerBound.utf16Offset(in: $0) }
        #expect(Set(offsets).count == 1)
    }

    @Test("table adds an ERROR column only when something failed, on a single line")
    func tableErrors() {
        #expect(!Formatters.table([ok], algorithms: [.phash, .oshash]).contains("ERROR"))
        let text = Formatters.table([ok, bad], algorithms: [.phash, .oshash])
        #expect(text.contains("ERROR"))
        #expect(text.contains("line1 line2"))
        #expect(text.split(separator: "\n").count == 3)
    }

    @Test("durations format as h:mm:ss")
    func duration() {
        #expect(Formatters.formatDuration(nil) == "-")
        #expect(Formatters.formatDuration(5) == "0:00:05")
        #expect(Formatters.formatDuration(3661) == "1:01:01")
    }
}

import XCTest
@testable import Cove

final class WeatherTests: XCTestCase {
    func testParsesOpenMeteoResponse() throws {
        let json = """
        {"current":{"temperature_2m":23.6,"weather_code":2,"is_day":1},
         "daily":{"temperature_2m_max":[28.2],"temperature_2m_min":[18.9]}}
        """
        let snapshot = try XCTUnwrap(WeatherModule.parse(Data(json.utf8)))
        XCTAssertEqual(snapshot, .init(temperature: 24, high: 28, low: 19, symbol: "cloud.sun.fill"))
    }

    func testNightAndUnknownCodes() {
        XCTAssertEqual(WeatherModule.symbol(for: 0, isDay: false), "moon.stars.fill")
        XCTAssertEqual(WeatherModule.symbol(for: 95, isDay: true), "cloud.bolt.rain.fill")
        XCTAssertEqual(WeatherModule.symbol(for: 1234, isDay: true), "cloud.fill")
    }

    func testRejectsIncompleteResponse() {
        XCTAssertNil(WeatherModule.parse(Data(#"{"current":{}}"#.utf8)))
    }
}

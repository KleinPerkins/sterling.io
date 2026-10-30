import Foundation
import Testing
@testable import SterlingUpdateSupport

struct UpdateConfigurationTests {
  let key = Data(repeating: 7, count: 32).base64EncodedString()
  var valid: [String: Any] {
    ["SterlingDistributionBuild": true, "SUFeedURL": UpdateConfiguration.feed, "SUPublicEDKey": key]
  }
  @Test func configuredDistributionAllowsUpdates() {
    #expect(UpdateConfiguration(info: valid, isProbe: false)?.publicKey == key)
  }
  @Test func probesNeverEnableNetworking() {
    #expect(UpdateConfiguration(info: valid, isProbe: true) == nil)
  }
  @Test func localBuildsNeverEnableNetworking() {
    var info = valid
    info["SterlingDistributionBuild"] = false
    #expect(UpdateConfiguration(info: info, isProbe: false) == nil)
  }
  @Test func foreignFeedsAndMalformedKeysAreRejected() {
    var info = valid
    info["SUFeedURL"] = "https://example.com/appcast.xml"
    #expect(UpdateConfiguration(info: info, isProbe: false) == nil)
    info = valid
    info["SUPublicEDKey"] = "invalid"
    #expect(UpdateConfiguration(info: info, isProbe: false) == nil)
    info["SUPublicEDKey"] = Data(repeating: 7, count: 31).base64EncodedString()
    #expect(UpdateConfiguration(info: info, isProbe: false) == nil)
  }
}

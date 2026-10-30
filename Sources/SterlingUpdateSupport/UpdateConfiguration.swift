import Foundation

public struct UpdateConfiguration: Equatable, Sendable {
  public static let feed = "https://github.com/KleinPerkins/sterling.io/releases/latest/download/appcast.xml"
  public let publicKey: String

  public init?(info: [String: Any], isProbe: Bool) {
    guard !isProbe,
      info["SterlingDistributionBuild"] as? Bool == true,
      info["SUFeedURL"] as? String == Self.feed,
      let key = info["SUPublicEDKey"] as? String,
      let bytes = Data(base64Encoded: key), bytes.count == 32
    else { return nil }
    publicKey = key
  }
}

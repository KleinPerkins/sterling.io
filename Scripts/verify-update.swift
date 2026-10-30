import CryptoKit
import Foundation

func verify(publicKey: Data, signature: Data, data: Data) throws -> Bool {
  let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
  return key.isValidSignature(signature, for: data)
}
let arguments = CommandLine.arguments
if arguments.count == 2 && arguments[1] == "--self-test" {
  let key = Curve25519.Signing.PrivateKey()
  let original = Data("Sterling update verification".utf8)
  let signature = try key.signature(for: original)
  guard try verify(publicKey: key.publicKey.rawRepresentation, signature: signature, data: original),
        try !verify(publicKey: key.publicKey.rawRepresentation, signature: signature, data: Data("tampered".utf8))
  else { fatalError("Update signature verification failed") }
  print("Update signature verifier accepts intact data and rejects tampering.")
} else {
  guard arguments.count == 4,
        let key = Data(base64Encoded: arguments[1]),
        let signature = Data(base64Encoded: arguments[2]),
        try verify(publicKey: key, signature: signature, data: Data(contentsOf: URL(fileURLWithPath: arguments[3])))
  else { fputs("Invalid update signature\n", stderr); exit(1) }
  print("Update signature verified.")
}

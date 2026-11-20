import Foundation

/// Detects key material in a content preview before it is sent to the LLM.
public enum SecretScanner {
    private static let markers = ["-----BEGIN", "PRIVATE KEY", "\"private_key\"", "aws_secret_access_key", "\"client_secret\""]

    public static func containsSecret(_ text: String) -> Bool {
        markers.contains { text.contains($0) }
    }
}

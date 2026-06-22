import SwiftUI

/// Shared colors and gradients for the app's look.
enum Theme {
    static let accent = Color(red: 0.40, green: 0.49, blue: 1.0)        // indigo

    static let commandGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.52, blue: 0.36),
                 Color(red: 0.97, green: 0.33, blue: 0.47)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let folderGradient = LinearGradient(
        colors: [Color(red: 0.42, green: 0.52, blue: 1.0),
                 Color(red: 0.55, green: 0.42, blue: 0.98)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

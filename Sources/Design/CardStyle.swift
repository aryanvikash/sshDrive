import SwiftUI

extension View {
    /// The frosted, rounded card used by the editor and confirmation dialogs.
    func modalCard(maxWidth: CGFloat = 300) -> some View {
        padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
            )
            .frame(maxWidth: maxWidth)
    }

    /// The subtle inset background used for text fields and inputs.
    func inputFieldBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1))
        )
    }
}

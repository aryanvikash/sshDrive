import SwiftUI

/// Back button + centered title + optional trailing control, used by the
/// Trash and Settings sub-pages.
struct PageHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 12, weight: .semibold))
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                        Text("Back").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                Spacer()
                trailing()
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

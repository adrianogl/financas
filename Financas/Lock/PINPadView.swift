import SwiftUI

struct PINPadView: View {
    let title: String
    var message: String?
    var isLocked = false
    var rejectionCount = 0
    var leadingAction: PINPadAction?
    let onComplete: (String) -> Void

    @State private var entry = ""

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 14) {
                Text(title)
                    .font(.title3.bold())
                dots
                Text(message ?? " ")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 36, alignment: .top)
            }
            .keyframeAnimator(initialValue: 0.0, trigger: rejectionCount) { content, offset in
                content.offset(x: offset)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(14, duration: 0.06)
                    LinearKeyframe(-12, duration: 0.06)
                    LinearKeyframe(8, duration: 0.06)
                    LinearKeyframe(0, duration: 0.06)
                }
            }

            GlassEffectContainer(spacing: 16) {
                Grid(horizontalSpacing: 24, verticalSpacing: 16) {
                    ForEach(LockConstants.keypadRows, id: \.self) { row in
                        GridRow {
                            ForEach(row, id: \.self) { digit in
                                digitKey(digit)
                            }
                        }
                    }
                    GridRow {
                        leadingKey
                        digitKey("0")
                        deleteKey
                    }
                }
            }
        }
        .sensoryFeedback(.error, trigger: rejectionCount)
        .onChange(of: rejectionCount) { entry = "" }
    }

    private var dots: some View {
        HStack(spacing: 18) {
            ForEach(0..<LockConstants.pinLength, id: \.self) { index in
                Circle()
                    .fill(index < entry.count ? Theme.accent : .clear)
                    .stroke(Theme.accent, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(entry.count) de \(LockConstants.pinLength) dígitos")
    }

    private func digitKey(_ digit: String) -> some View {
        Button {
            append(digit)
        } label: {
            Text(digit)
                .font(.title.weight(.medium))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(isLocked)
    }

    @ViewBuilder
    private var leadingKey: some View {
        if let leadingAction {
            Button(action: leadingAction.perform) {
                Image(systemName: leadingAction.systemImage)
                    .font(.title2)
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .accessibilityLabel(leadingAction.title)
        } else {
            Color.clear.frame(width: 64, height: 64)
        }
    }

    private var deleteKey: some View {
        Button("Apagar") {
            entry = String(entry.dropLast())
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Theme.accent)
        .frame(width: 64, height: 64)
        .opacity(entry.isEmpty ? 0 : 1)
        .disabled(entry.isEmpty)
    }

    private func append(_ digit: String) {
        guard entry.count < LockConstants.pinLength else { return }
        entry.append(digit)
        if entry.count == LockConstants.pinLength {
            onComplete(entry)
        }
    }
}

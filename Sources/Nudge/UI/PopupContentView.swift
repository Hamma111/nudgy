import SwiftUI

enum PopupPreset: String, CaseIterable, Identifiable {
    case minimal  = "Minimal"
    case pill     = "Pill"
    case glass    = "Glass"
    case card     = "Card"
    case banner   = "Banner"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .minimal: return "Tiny dark chip"
        case .pill:    return "Colorful status badge"
        case .glass:   return "Frosted panel with blur"
        case .card:    return "Full detail card"
        case .banner:  return "Wide macOS-style banner"
        }
    }
}

struct PopupContentView: View {
    let item: NotificationItem
    let onDismiss: () -> Void
    let onAction: (NotificationAction) -> Void
    var preset: PopupPreset = .minimal

    var body: some View {
        switch preset {
        case .minimal: PresetMinimal(item: item, onDismiss: onDismiss)
        case .pill:    PresetPill(item: item, onDismiss: onDismiss)
        case .glass:   PresetGlass(item: item, onDismiss: onDismiss)
        case .card:    PresetCard(item: item, onDismiss: onDismiss)
        case .banner:  PresetBanner(item: item, onDismiss: onDismiss)
        }
    }
}

// ────────────────────────────────────────────
// 1. MINIMAL — tiny dark chip, icon + title only
// ────────────────────────────────────────────

private struct PresetMinimal: View {
    let item: NotificationItem
    let onDismiss: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.style.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(item.style.color)

            Text(item.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text(item.projectName)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.3))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white.opacity(hovered ? 0.4 : 0.12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.11)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovered = h } }
    }
}

// ────────────────────────────────────────────
// 2. PILL — colorful capsule with tinted background
// ────────────────────────────────────────────

private struct PresetPill: View {
    let item: NotificationItem
    let onDismiss: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: item.style.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)

            Text(item.title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.white)

            Text(item.projectName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(item.style.color.opacity(0.85))
        )
        .shadow(color: item.style.color.opacity(0.4), radius: 8, y: 2)
        .onTapGesture { onDismiss() }
    }
}

// ────────────────────────────────────────────
// 3. GLASS — frosted wide panel, icon circle, two lines
// ────────────────────────────────────────────

private struct PresetGlass: View {
    let item: NotificationItem
    let onDismiss: () -> Void
    @State private var hovered = false

    private var subtitle: String {
        if !item.message.isEmpty { return item.message }
        if !item.projectName.isEmpty { return item.projectName }
        return ""
    }

    var body: some View {
        HStack(spacing: 10) {
            // Large icon circle
            ZStack {
                Circle()
                    .fill(item.style.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: item.style.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.style.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(hovered ? 0.5 : 0.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 260)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .environment(\.colorScheme, .dark)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovered = h } }
    }
}

// ────────────────────────────────────────────
// 4. CARD — full dark card, thick colored left border, all details
// ────────────────────────────────────────────

private struct PresetCard: View {
    let item: NotificationItem
    let onDismiss: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Thick accent edge
            item.style.color
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(item.style.color)
                        .tracking(0.5)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(hovered ? 0.5 : 0.15))
                    }
                    .buttonStyle(.plain)
                }

                Text(item.projectName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                if !item.message.isEmpty {
                    Text(item.message)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 200)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.white.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .onHover { hovered = $0 }
    }
}

// ────────────────────────────────────────────
// 5. BANNER — wide, light, macOS notification style
// ────────────────────────────────────────────

private struct PresetBanner: View {
    let item: NotificationItem
    let onDismiss: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            // "App icon"
            RoundedRectangle(cornerRadius: 6)
                .fill(item.style.color.gradient)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("NUDGY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("now")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Text("\(item.title) — \(item.projectName)")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if !item.message.isEmpty {
                    Text(item.message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 300)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .onTapGesture { onDismiss() }
    }
}

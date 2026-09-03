import SwiftUI
import UIKit

/// The songr look, extracted verbatim from the songr web UI in
/// /Users/michael/Dev/roon-controller (read-only reference):
///   - ui/src/app.css                          — the `--songr-*` color tokens
///     (dark `:root` block) and the font stack ('Avenir Next', 'Trebuchet MS',
///     'Gill Sans'); Avenir Next ships on iOS, so the first choice is exact.
///   - ui/src/routes/library/unified-surface.css — layout metrics: header bar,
///     scope chips (.sc), letter rail (.rail + --rw/--rs/--rf), artist rows
///     (.arow/.an/.ad/.ac), letter group headings (.gl), album tiles
///     (.tiles/.tile/.tt/.ta/.mono-tile), track rows (.tr/.tn/.tnm), player
///     bar (.player/.npt/.nps/.tp .big), panel (.pt/.pa/.pb).
///   - ui/src/lib/components/NowPlayingOverlay.svelte — full now-playing:
///     np-dialog panel, 6px progress bar, 44/56pt round controls, np-title.
/// Touch sizing follows the web's `data-d="pi"` profile (its touchscreen
/// tuning): 16px artist rows, 46px chips, bigger transport.
enum SongrTheme {
    // MARK: Colors — ui/src/app.css `:root` (dark)

    static let appBg = rgb(0x050505)          // --songr-app-bg
    static let bg = rgb(0x000000)             // --songr-bg
    static let header = rgb(0x000000)         // --songr-header
    static let rail = rgb(0x000000)           // --songr-rail
    static let panel = rgb(0x0B0B0B)          // --songr-panel
    static let inset = rgb(0x101010)          // --songr-inset
    static let surface11 = rgb(0x111111)      // --songr-surface-11
    static let control = rgb(0x121212)        // --songr-control
    static let raise = rgb(0x141414)          // --songr-raise
    static let surface16 = rgb(0x161616)      // --songr-surface-16
    static let hoverSubtle = rgb(0x181818)    // --songr-hover-subtle
    static let surface19 = rgb(0x191919)      // --songr-surface-19
    static let hover = rgb(0x1C1C1C)          // --songr-hover
    static let keyline = rgb(0x222222)        // --songr-keyline
    static let disabled = rgb(0x2B2B2B)       // --songr-disabled

    static let line = Color.white.opacity(0.09)        // --songr-line
    static let lineSubtle = Color.white.opacity(0.06)  // --songr-line-subtle
    static let line12 = Color.white.opacity(0.12)      // --songr-line-12
    static let line13 = Color.white.opacity(0.13)      // --songr-line-13
    static let lineStrong = Color.white.opacity(0.18)  // --songr-line-strong
    static let line20 = Color.white.opacity(0.2)       // --songr-line-20

    static let text = Color.white                       // --songr-text
    static let textHigh = Color.white.opacity(0.92)     // --songr-text-high
    static let text70 = Color.white.opacity(0.7)        // --songr-text-70
    static let text60 = Color.white.opacity(0.6)        // --songr-text-60
    static let text42 = Color.white.opacity(0.42)       // --songr-text-42
    static let textMid = rgb(0xC4C4C4)        // --songr-text-mid
    static let chipText = rgb(0xC9C9C9)       // --songr-chip-text
    static let controlText = rgb(0xD8D8D8)    // --songr-control-text
    static let listText = rgb(0xE2E2E2)       // --songr-list-text
    static let copy = rgb(0xDDDDDD)           // --songr-copy
    static let soft = rgb(0x9A9A9A)           // --songr-soft
    static let subtle = rgb(0x7C7C7C)         // --songr-subtle
    static let dim = rgb(0x5E5E5E)            // --songr-dim

    static let accent = rgb(0xC8A24A)         // --songr-accent
    static let gold = rgb(0xD4AF37)           // --songr-unified-accent
    static let accentBright = rgb(0xE6C674)   // --songr-accent-bright
    static let onAccent = rgb(0x101010)       // --songr-on-accent
    static let success = rgb(0x6EE7A8)        // --songr-success
    static let error = rgb(0xFF8A80)          // --songr-error

    static let scrim = Color.black.opacity(0.7)        // --songr-scrim
    static let shadow = Color.black.opacity(0.62)      // --songr-shadow

    // MARK: Type — 'Avenir Next' (app.css font-family, first choice)

    static func font(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .custom(weight.face, size: size)
    }

    enum Weight {
        case regular, medium, demiBold, bold, heavy
        var face: String {
            switch self {
            case .regular: return "AvenirNext-Regular"
            case .medium: return "AvenirNext-Medium"
            case .demiBold: return "AvenirNext-DemiBold"
            case .bold: return "AvenirNext-Bold"
            case .heavy: return "AvenirNext-Heavy"
            }
        }
    }

    // MARK: Shared metrics (unified-surface.css)

    /// .tile .art / panel .art border-radius: 4px.
    static let artRadius: CGFloat = 4
    /// .sc chip height, pi profile: 46px.
    static let chipHeight: CGFloat = 40
    /// .rail letter square, sized between the normal (32) and pi (44) profiles.
    static let railButton: CGFloat = 26
    static let railWidth: CGFloat = 30

    private static func rgb(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255)
    }
}

// MARK: - Recurring songr fragments

/// `.gl` — letter/group heading: 11px, 0.26em tracking, dim, hairline under.
struct SongrGroupHeading: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(SongrTheme.font(12, .demiBold))
                .tracking(3.5)
                .foregroundStyle(SongrTheme.dim)
            Rectangle()
                .fill(SongrTheme.lineSubtle)
                .frame(height: 1)
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(SongrTheme.bg)
    }
}

/// `.sc` — scope chip: pill, control background, hairline; gold when active.
struct SongrChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SongrTheme.font(15, isOn ? .demiBold : .regular))
                .foregroundStyle(isOn ? SongrTheme.onAccent : SongrTheme.chipText)
                .padding(.horizontal, 20)
                .frame(height: SongrTheme.chipHeight)
                .background(
                    Capsule().fill(isOn ? SongrTheme.accent : SongrTheme.control)
                )
                .overlay(
                    Capsule().strokeBorder(
                        isOn ? SongrTheme.accent : SongrTheme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// `.settingsbtn`/`.aboutbtn` — small letterspaced bordered text button.
struct SongrBarButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(SongrTheme.font(11, .medium))
                .tracking(1.8)
                .foregroundStyle(SongrTheme.dim)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(SongrTheme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// `.pb button` — panel action button (album page, settings, pickers).
struct SongrPanelButton: View {
    let label: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SongrTheme.font(14, .medium))
                .foregroundStyle(role == .destructive
                                 ? SongrTheme.error : SongrTheme.controlText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 7).fill(SongrTheme.surface16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(SongrTheme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// The gold call-to-action (link screen "Sign in with Plex").
struct SongrAccentButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SongrTheme.font(16, .demiBold))
                .foregroundStyle(SongrTheme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 8).fill(SongrTheme.accent))
        }
        .buttonStyle(.plain)
    }
}

/// The songr mark, ported from UnifiedLibraryMode.svelte `.brand`:
/// Younger Futhark long-branch runes ᛋᚬᚾᚴᚱ (s-o-n-k-r) at rest, tap flips
/// to the Latin spelling "Sǫngr" (13px / 0.18em in the original). Gold at
/// rest (owner ruling 2026-08-03 in the songr repo). `size` is the rune
/// height; the web mark renders at 15px.
struct SongrWordmark: View {
    var size: CGFloat = 15
    @State private var showsLatin = false

    var body: some View {
        Button {
            showsLatin.toggle()
        } label: {
            if showsLatin {
                Text("Sǫngr")
                    .font(SongrTheme.font(size * 13 / 15, .demiBold))
                    .tracking(size * 13 / 15 * 0.18)
                    .foregroundStyle(SongrTheme.accent)
            } else {
                SongrRuneMark()
                    .stroke(SongrTheme.accent, style: StrokeStyle(
                        lineWidth: max(size * 5 / 104, 1),
                        lineCap: .butt, lineJoin: .miter))
                    .frame(width: size * 320 / 104, height: size)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sǫngr")
    }
}

/// The inline-SVG rune paths from the songr web UI, verbatim
/// (viewBox 0 0 320 104; stroke-width 5 in viewBox units).
private struct SongrRuneMark: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 320, sy = rect.height / 104
        var p = Path()
        func m(_ x: CGFloat, _ y: CGFloat) { p.move(to: CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)) }
        func l(_ x: CGFloat, _ y: CGFloat) { p.addLine(to: CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)) }
        m(12, 2); l(12, 56); l(36, 34); l(36, 100)            // ᛋ
        m(88, 2); l(88, 100)                                  // ᚬ
        m(70, 22); l(124, 56)
        m(70, 46); l(124, 80)
        m(154, 2); l(154, 100)                                // ᚾ
        m(135, 35); l(186, 72)
        m(212, 2); l(212, 100)                                // ᚴ
        m(212, 48); l(242, 10)
        m(278, 2); l(278, 100)                                // ᚱ
        m(278, 2); l(308, 22); l(278, 44)
        m(280, 42); l(310, 100)
        return p
    }
}

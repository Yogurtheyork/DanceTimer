import SwiftUI
import CoreText

@main
struct TimerCamApp: App {
    init() {
        // Registered at runtime so the generated Info.plist needs no UIAppFonts entry.
        if let url = Bundle.main.url(forResource: "PlaywriteBEWALGuides-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        if let title = UIFont(name: Font.appFontName, size: 17) {
            appearance.titleTextAttributes = [.font: title]
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

extension Font {
    static let appFontName = "PlaywriteBEWALGuides-Regular"

    /// The app's font, scaled with Dynamic Type like the matching system text style.
    static func app(_ style: TextStyle = .body, size: CGFloat? = nil) -> Font {
        let base: CGFloat = switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
        return .custom(appFontName, size: size ?? base, relativeTo: style)
    }
}

import SwiftUI
import UIKit

enum ImobChrome {

    @MainActor
    static func configure() {
        let selected = UIColor(Color.accentColor)
        let normal = UIColor(Color.appSecondaryText)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        applyTabItemColors(to: appearance.stackedLayoutAppearance, selected: selected, normal: normal)
        applyTabItemColors(to: appearance.inlineLayoutAppearance, selected: selected, normal: normal)
        applyTabItemColors(to: appearance.compactInlineLayoutAppearance, selected: selected, normal: normal)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = selected
        tabBar.unselectedItemTintColor = normal
    }

    @MainActor
    private static func applyTabItemColors(
        to itemAppearance: UITabBarItemAppearance,
        selected: UIColor,
        normal: UIColor
    ) {
        itemAppearance.normal.iconColor = normal
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: normal]
        itemAppearance.selected.iconColor = selected
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
    }
}

extension View {
    func imobAppearance() -> some View {
        preferredColorScheme(.dark)
            .tint(.accentColor)
            .onAppear(perform: ImobChrome.configure)
    }

    func imobContentStyle() -> some View {
        foregroundStyle(Color.appPrimaryText, Color.appSecondaryText, Color.appSecondaryText)
    }

    func imobCanvas() -> some View {
        background(Color.appBackground)
            .imobAppearance()
            .imobContentStyle()
    }

    func imobListCanvas() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .imobAppearance()
            .imobContentStyle()
    }

    func imobSurface() -> some View {
        listRowBackground(Color.appSurface)
    }

    func imobPrimaryButton() -> some View {
        buttonStyle(.borderedProminent)
            .tint(.accentColor)
    }
}

struct ImobExpandingPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isExpanded = false
    @State private var showsTitle = false

    private let collapsedSize: CGFloat = 56

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                if showsTitle {
                    Text(title)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
        }
        .imobPrimaryButton()
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .frame(maxWidth: isExpanded ? .infinity : collapsedSize)
        .frame(height: collapsedSize)
        .clipShape(Capsule())
        .accessibilityLabel(title)
        .task {
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.smooth(duration: 0.55)) {
                isExpanded = true
            }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.smooth(duration: 0.25)) {
                showsTitle = true
            }
        }
    }
}

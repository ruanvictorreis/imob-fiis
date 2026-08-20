import SwiftUI

extension View {
    func imobCanvas() -> some View {
        background(Color.appBackground)
    }

    func imobListCanvas() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.appBackground)
    }

    func imobSurface() -> some View {
        listRowBackground(Color.appSurface)
    }

    func imobPrimaryButton() -> some View {
        buttonStyle(.borderedProminent)
            .tint(.accentColor)
    }
}

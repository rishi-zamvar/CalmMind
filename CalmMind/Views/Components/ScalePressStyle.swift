import SwiftUI

/// Button style that scales down on press for tactile feedback
struct ScalePressStyle: ButtonStyle {
    let scale: CGFloat

    init(scale: CGFloat = 0.98) {
        self.scale = scale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(DesignTokens.defaultAnimation, value: configuration.isPressed)
    }
}

#Preview {
    Button("Press Me") {
        print("Tapped")
    }
    .buttonStyle(ScalePressStyle())
    .padding()
}

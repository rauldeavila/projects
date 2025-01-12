import SwiftUI

struct CRTEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(GrainView().blendMode(.overlay))
            .overlay(ScanLinesView().blendMode(.multiply))
            .overlay(ChromaticAberrationView())
            .overlay(BleedView())
    }
}

struct GrainView: View {
    @State private var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @State private var grainOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.black, .white]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask(
                    Image("grain")
                        .resizable()
                        .scaledToFill()
                        .offset(x: grainOffset, y: grainOffset)
                )
                .onReceive(timer) { _ in
                    grainOffset = CGFloat.random(in: -10...10)
                }
        }
    }
}

struct ScanLinesView: View {
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var scanLineOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.black, .white]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask(
                    Image("scanlines")
                        .resizable()
                        .scaledToFill()
                        .offset(y: scanLineOffset)
                )
                .onReceive(timer) { _ in
                    scanLineOffset = CGFloat.random(in: -5...5)
                }
        }
    }
}

struct ChromaticAberrationView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.red
                    .blendMode(.screen)
                    .offset(x: -1, y: -1)
                Color.green
                    .blendMode(.screen)
                    .offset(x: 1, y: 1)
                Color.blue
                    .blendMode(.screen)
                    .offset(x: 1, y: -1)
            }
        }
    }
}

struct BleedView: View {
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.white.opacity(0.1), .clear]),
                        center: .center,
                        startRadius: 0,
                        endRadius: geometry.size.width / 2
                    )
                )
        }
    }
}

import SwiftUI
import MetalKit

struct CRTOverlayView: View {
    @State private var isCRTEnabled = false

    var body: some View {
        ZStack {
            if isCRTEnabled {
                MetalView()
                    .edgesIgnoringSafeArea(.all)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        isCRTEnabled.toggle()
                    }) {
                        Text(isCRTEnabled ? "Disable CRT" : "Enable CRT")
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
        }
    }
}

struct MetalView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?

        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
            setupMetal()
        }

        func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else { return }
            commandQueue = device.makeCommandQueue()

            let library = device.makeDefaultLibrary()
            let vertexFunction = library?.makeFunction(name: "vertexShader")
            let fragmentFunction = library?.makeFunction(name: "fragmentShader")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let pipelineState = pipelineState,
                  let commandQueue = commandQueue else { return }

            let commandBuffer = commandQueue.makeCommandBuffer()
            let renderPassDescriptor = view.currentRenderPassDescriptor

            if let renderPassDescriptor = renderPassDescriptor {
                let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
                renderEncoder?.setRenderPipelineState(pipelineState)
                renderEncoder?.endEncoding()
                commandBuffer?.present(drawable)
            }

            commandBuffer?.commit()
        }
    }
}

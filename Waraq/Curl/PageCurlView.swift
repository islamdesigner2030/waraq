import MetalKit
import UIKit

/// Renders one sheet of paper bent around a cylinder, with the back side, lighting and
/// a cast shadow, from a snapshot of the live page. Driven frame-by-frame by the reader.
final class PageCurlView: MTKView {
    private var queue: MTLCommandQueue?
    private var pagePipeline: MTLRenderPipelineState?
    private var shadowPipeline: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    private var sampler: MTLSamplerState?
    private var meshBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount = 0
    private var texture: MTLTexture?
    private var loader: MTKTextureLoader?

    var uniforms = CurlUniforms()
    private(set) var isReady = false

    init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        configure()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        isOpaque = false
        layer.isOpaque = false
        isUserInteractionEnabled = false
        isPaused = true
        enableSetNeedsDisplay = false
        autoResizeDrawable = true
        framebufferOnly = true
        presentsWithTransaction = true
        colorPixelFormat = .bgra8Unorm
        depthStencilPixelFormat = .depth32Float
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        clearDepth = 1

        guard let device else { return }
        sampleCount = device.supportsTextureSampleCount(4) ? 4 : 1
        queue = device.makeCommandQueue()
        loader = MTKTextureLoader(device: device)

        guard let library = device.makeDefaultLibrary(),
              let pageV = library.makeFunction(name: "curlVertex"),
              let pageF = library.makeFunction(name: "curlFragment"),
              let shadowV = library.makeFunction(name: "shadowVertex"),
              let shadowF = library.makeFunction(name: "shadowFragment") else { return }

        func pipeline(_ v: MTLFunction, _ f: MTLFunction) -> MTLRenderPipelineState? {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = v
            d.fragmentFunction = f
            d.rasterSampleCount = sampleCount
            d.depthAttachmentPixelFormat = depthStencilPixelFormat
            let c = d.colorAttachments[0]!
            c.pixelFormat = colorPixelFormat
            c.isBlendingEnabled = true
            c.rgbBlendOperation = .add
            c.alphaBlendOperation = .add
            c.sourceRGBBlendFactor = .one
            c.sourceAlphaBlendFactor = .one
            c.destinationRGBBlendFactor = .oneMinusSourceAlpha
            c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: d)
        }
        pagePipeline = pipeline(pageV, pageF)
        shadowPipeline = pipeline(shadowV, shadowF)

        let ds = MTLDepthStencilDescriptor()
        ds.depthCompareFunction = .less
        ds.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: ds)

        let sd = MTLSamplerDescriptor()
        sd.minFilter = .linear
        sd.magFilter = .linear
        sd.sAddressMode = .clampToEdge
        sd.tAddressMode = .clampToEdge
        sampler = device.makeSamplerState(descriptor: sd)

        buildMesh(device: device, columns: 44, rows: 60)
        isReady = pagePipeline != nil && shadowPipeline != nil && depthState != nil && meshBuffer != nil
    }

    private func buildMesh(device: MTLDevice, columns: Int, rows: Int) {
        var uvs: [SIMD2<Float>] = []
        uvs.reserveCapacity((columns + 1) * (rows + 1))
        for j in 0...rows {
            for i in 0...columns {
                uvs.append(SIMD2(Float(i) / Float(columns), Float(j) / Float(rows)))
            }
        }
        var indices: [UInt16] = []
        indices.reserveCapacity(columns * rows * 6)
        let stride = columns + 1
        for j in 0..<rows {
            for i in 0..<columns {
                let a = UInt16(j * stride + i)
                let b = UInt16(j * stride + i + 1)
                let c = UInt16((j + 1) * stride + i)
                let d = UInt16((j + 1) * stride + i + 1)
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        indexCount = indices.count
        meshBuffer = uvs.withUnsafeBytes { raw in
            device.makeBuffer(bytes: raw.baseAddress!, length: raw.count, options: .storageModeShared)
        }
        indexBuffer = indices.withUnsafeBytes { raw in
            device.makeBuffer(bytes: raw.baseAddress!, length: raw.count, options: .storageModeShared)
        }
    }

    /// Loads the page snapshot that will be bent.
    func load(snapshot: UIImage) -> Bool {
        guard isReady, let loader, let cg = snapshot.cgImage else { return false }
        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: NSNumber(value: false),
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ]
        texture = try? loader.newTexture(cgImage: cg, options: options)
        return texture != nil
    }

    func releaseTexture() { texture = nil }

    override func draw(_ rect: CGRect) {
        guard isReady,
              let queue, let pagePipeline, let shadowPipeline, let texture,
              let meshBuffer, let indexBuffer,
              let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }

        var u = uniforms
        u.viewSize = SIMD2(Float(bounds.width), Float(bounds.height))
        let size = MemoryLayout<CurlUniforms>.stride

        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)

        encoder.setRenderPipelineState(shadowPipeline)
        encoder.setVertexBytes(&u, length: size, index: 1)
        encoder.setFragmentBytes(&u, length: size, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        encoder.setRenderPipelineState(pagePipeline)
        encoder.setVertexBuffer(meshBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&u, length: size, index: 1)
        encoder.setFragmentBytes(&u, length: size, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint16,
                                      indexBuffer: indexBuffer, indexBufferOffset: 0)
        encoder.endEncoding()

        // presentsWithTransaction keeps the curl in step with the UIKit page views,
        // so swapping between the live page and the rendered sheet never flickers.
        commands.commit()
        commands.waitUntilScheduled()
        drawable.present()
    }
}

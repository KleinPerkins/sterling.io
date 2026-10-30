import AppKit
@preconcurrency import MetalKit
import SpriteKit
import SterlingCore

final class RenderMetrics: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  private var gpu: [Double] = []
  func frame(gpuMilliseconds: Double) {
    lock.lock()
    defer { lock.unlock() }
    count += 1
    if gpu.count < 5_000 { gpu.append(gpuMilliseconds) }
  }
  func summary() -> (frames: Int, p95GPU: Double) {
    lock.lock()
    defer { lock.unlock() }
    let sorted = gpu.sorted()
    return (
      count, sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
    )
  }
}

@MainActor final class CatRenderer: NSObject, MTKViewDelegate {
  let scene: CatScene
  let renderer: SKRenderer
  let queue: any MTLCommandQueue
  let metrics = RenderMetrics()
  var clock: () -> Double = { ProcessInfo.processInfo.systemUptime }
  init(view: MTKView, interactive: Bool) throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw PrototypeError.noGPU
    }
    self.queue = queue
    self.renderer = SKRenderer(device: device)
    scene = CatScene(size: view.bounds.size)
    scene.interactive = interactive
    super.init()
    view.device = device
    view.colorPixelFormat = .bgra8Unorm
    view.depthStencilPixelFormat = .invalid
    view.framebufferOnly = false
    view.clearColor = MTLClearColorMake(0, 0, 0, 0)
    view.layer?.isOpaque = false
    view.preferredFramesPerSecond = 30
    renderer.scene = scene
    view.delegate = self
  }
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    scene.size = view.bounds.size
  }
  func draw(in view: MTKView) {
    guard view.bounds.width > 0, view.bounds.height > 0, let drawable = view.currentDrawable,
      let pass = view.currentRenderPassDescriptor, let buffer = queue.makeCommandBuffer()
    else { return }
    scene.size = view.bounds.size
    let now = clock()
    scene.pose(at: now)
    renderer.update(atTime: now)
    renderer.render(
      withViewport: CGRect(origin: .zero, size: view.drawableSize), commandBuffer: buffer,
      renderPassDescriptor: pass)
    let metrics = self.metrics
    buffer.addCompletedHandler { b in
      metrics.frame(gpuMilliseconds: max(0, (b.gpuEndTime - b.gpuStartTime) * 1_000))
    }
    buffer.present(drawable)
    buffer.commit()
  }
  /// Export only our scene, never capture desktop pixels or other applications.
  func exportPNG(to url: URL, size: CGSize = CGSize(width: 1_040, height: 560)) throws {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    guard let texture = queue.device.makeTexture(descriptor: descriptor),
      let buffer = queue.makeCommandBuffer()
    else { throw PrototypeError.noGPU }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    let old = scene.size
    scene.size = CGSize(width: size.width / 2, height: size.height / 2)
    scene.pose(at: 10)
    renderer.update(atTime: 10)
    renderer.render(
      withViewport: CGRect(origin: .zero, size: size), commandBuffer: buffer,
      renderPassDescriptor: pass)
    buffer.commit()
    buffer.waitUntilCompleted()
    scene.size = old
    guard buffer.status == .completed else { throw PrototypeError.renderFailed }
    var bytes = [UInt8](repeating: 0, count: Int(size.width * size.height * 4))
    bytes.withUnsafeMutableBytes { ptr in
      texture.getBytes(
        ptr.baseAddress!, bytesPerRow: Int(size.width) * 4,
        from: MTLRegionMake2D(0, 0, Int(size.width), Int(size.height)), mipmapLevel: 0)
    }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
      let image = CGImage(
        width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(
          .byteOrder32Little), provider: provider, decode: nil, shouldInterpolate: true,
        intent: .defaultIntent),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { throw PrototypeError.renderFailed }
    try data.write(to: url, options: .atomic)
  }
}

enum PrototypeError: Error { case noGPU, renderFailed }

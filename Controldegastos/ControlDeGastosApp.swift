import SwiftUI
import AppKit

@main
struct ControlDeGastosApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    // Carga y recorta la imagen con las esquinas redondeadas de macOS
                    if let imagePath = Bundle.main.path(forResource: "app_icon", ofType: "png"),
                       let originalImage = NSImage(contentsOfFile: imagePath) {
                        
                        let targetSize = NSSize(width: 512, height: 512)
                        let roundedImage = NSImage(size: targetSize)
                        
                        roundedImage.lockFocus()
                        let rect = NSRect(origin: .zero, size: targetSize)
                        // Máscara con el radio de curvatura estándar de Mac
                        let clipPath = NSBezierPath(roundedRect: rect, xRadius: 110, yRadius: 110)
                        clipPath.addClip()
                        
                        originalImage.draw(in: rect)
                        roundedImage.unlockFocus()
                        
                        // Asigna la imagen redondeada al Dock
                        NSApplication.shared.applicationIconImage = roundedImage
                    }
                }
        }
    }
}

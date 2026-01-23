import SwiftUI
import AVKit

struct AudioPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemCyan
        // Use .label or .link (system blue) so it's visible on both light/dark backgrounds
        picker.tintColor = .label 
        picker.backgroundColor = .clear
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

import SwiftUI
import AVKit

struct AudioPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemCyan
        picker.tintColor = .white
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

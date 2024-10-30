//
//  View+UIView.swift
//  BasicVideoChatSwiftUI
//
//  Created by Abdul Ajetunmobi on 29/10/2024.
//

import SwiftUI
import PencilKit

struct OTView: UIViewRepresentable {
    @State var view: UIView
    
    func makeUIView(context: Context) -> UIView {
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        Task { @MainActor in
            self.view = uiView
        }
    }
}

struct MyCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 15)
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        Task { @MainActor in
            self.canvasView = canvasView
        }
    }
}

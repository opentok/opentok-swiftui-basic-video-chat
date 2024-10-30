//
//  AnnotationView.swift
//  BasicVideoChatSwiftUI
//
//  Created by Abdul Ajetunmobi on 29/10/2024.
//

import SwiftUI
import Combine
import PencilKit

struct AnnotationView: View {
    @Environment(\.undoManager) private var undoManager
    @ObservedObject var canvasManager = CanvasManager()
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Button("Clear") {
                    // This is only local
                    canvasManager.clear()
                }
                Button("Undo") {
                    // This is only local
                    undoManager?.undo()
                }
                Button("Redo") {
                    // This is only local
                    undoManager?.redo()
                }
            }
            MyCanvas(canvasView: $canvasManager.canvasView)
        }.padding(16)
    }
}

final class CanvasManager: NSObject, ObservableObject, PKCanvasViewDelegate {
    @Published var canvasView = PKCanvasView()
    private var subscriptions = Set<AnyCancellable>()
    private let otManager = OpenTokManager.shared
    
    override init() {
        super.init()
        self.canvasView.delegate = self
        otManager.onAnnotation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                self?.addStroke(points: points)
            }.store(in: &subscriptions)
    }
    
    @MainActor
    func clear() {
        canvasView.drawing = PKDrawing()
    }
    
    @MainActor
    func addStroke(points: [PKStrokePoint]) {
        let ink = PKInk(.pen, color: .blue)
        let path = PKStrokePath(controlPoints: points, creationDate: .distantPast)
        let stroke = PKStroke(ink: ink, path: path)
        let drawing = PKDrawing(strokes: [stroke])
        canvasView.drawing.append(drawing)
    }
    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if let newStroke = canvasView.drawing.strokes.last, isRecent(updateDate: newStroke.path.creationDate) {
            let body = AnnotationBody(senderID: otManager.annotatorSignalID, points: Array(newStroke.path))
            OpenTokManager.shared.sendSignal(body: body)
        }
    }
    
    private func isRecent(updateDate: Date) -> Bool {
        let currentDate = Date()
        let timeInterval = currentDate.timeIntervalSince(updateDate)
        return timeInterval <= 60
    }
}

#Preview {
    AnnotationView()
}

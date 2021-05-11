//
//  ContentView.swift
//  BasicVideoChatSwiftUI
//
//  Created by Abdulhakim Ajetunmobi on 10/05/2021.
//

import SwiftUI

struct OTErrorWrapper: Identifiable {
    var id = UUID()
    let error: String
}

struct OTView: UIViewRepresentable {
    @State var view: UIView
    
    func makeUIView(context: Context) -> UIView {
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            self.view = uiView
        }
    }
}

struct ContentView: View {
    @ObservedObject var otManager = OpenTokManager()
    
    var body: some View {
        VStack {
            otManager.pubview.flatMap { view in
                OTView(view: view)
                    .frame(width: 200, height: 200, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
            }.cornerRadius(5.0)
            otManager.subview.flatMap { view in
                OTView(view: view)
                    .frame(width: 200, height: 200, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
            }.cornerRadius(5.0)
        }
        .alert(item: $otManager.error, content: { error -> Alert in
            Alert(title: Text("OpenTok Error"), message: Text(error.error), dismissButton: .default(Text("Ok")))
        })
        .animation(.default)
        .onAppear(perform: {
            otManager.setup()
        })
    }
}

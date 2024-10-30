//
//  ContentView.swift
//  BasicVideoChatSwiftUI
//
//  Created by Abdulhakim Ajetunmobi on 10/05/2021.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var otManager = OpenTokManager.shared
    @State private var isAnnotationViewPresented = false
    
    var body: some View {
        NavigationStack {
            Group {
                VStack {
                    otManager.pubView.flatMap { view in
                        OTView(view: view)
                            .frame(width: 200, height: 200, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    }.cornerRadius(5.0)
                    otManager.subView.flatMap { view in
                        OTView(view: view)
                            .frame(width: 200, height: 200, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    }.cornerRadius(5.0)
                    Spacer()
                    Button("Annotate") {
                        isAnnotationViewPresented = true
                    }
                }.padding(16)
            }
            .navigationDestination(isPresented: $isAnnotationViewPresented) {
                AnnotationView()
            }
        }
        .alert(item: $otManager.error, content: { error -> Alert in
            Alert(title: Text("OpenTok Error"), message: Text(error.error), dismissButton: .default(Text("OK")))
        })
    }
}

//
//  ContentView.swift
//  projects
//
//  Created by Raul de Avila Junior on 06/01/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack (alignment: .leading) {
            HStack {
                Text("TODO").font(.headline).bold()
                Text("A task example. Maybe it takes a lot of horizontal space, maybe not.")
            }
            
            HStack {
                Text("TODO").font(.headline).bold()
                Text("Another task, this one is smaller.")
            }
            
            HStack {
                Text("TODO").font(.headline).bold()
                Text("This is other task that's kinda big, a bit smaller than the first.")
            }
            
        }

    }
}

#Preview {
    ContentView()
}

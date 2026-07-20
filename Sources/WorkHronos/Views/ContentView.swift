import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            TimerBarView()
                .padding()
                .zIndex(10)
            Divider()
            WeekHistoryView()
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 480, idealHeight: 560)
        .onAppear { DockIcon.update(running: store.running != nil) }
        .onChange(of: store.running) { _, running in
            DockIcon.update(running: running != nil)
        }
        // Namerno bez .onDisappear: on se okida i kad se samo zatvori glavni prozor
        // (app živi dalje ako je Week Summary otvoren), pa bi ugasio ikonicu iako timer radi.
        // Povratak na setup/unavailable ionako pokrivaju te grane u RootView-u.
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

import SwiftUI

struct ErrorAlert: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    func body(content: Content) -> some View {
        content
            .alert(isPresented: $isPresented) {
                Alert(title: Text("Error"), message: Text(message), dismissButton: .default(Text("OK")))
            }
    }
}

extension View {
    func errorAlert(isPresented: Binding<Bool>, message: String) -> some View {
        self.modifier(ErrorAlert(isPresented: isPresented, message: message))
    }
} 
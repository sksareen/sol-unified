import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // Enable developer extras for debugging if needed
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        nsView.load(request)
    }
}

struct AgentConsoleView: View {
    var body: some View {
        WebView(url: URL(string: "http://localhost:5173")!)
            .background(Color.black)
    }
}


import SwiftUI

/// The version, the links that a store app needs, and the notice of the one dependency (D063, D135). Each link opens
/// only after a tap.
struct AboutPage: View {
    static let privacyURL = URL(string: "https://maru.day/privacy.html")
    static let supportURL = URL(string: "https://maru.day/support.html")

    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(verbatim: Self.version)
                }
                if let url = Self.supportURL { Link("Support", destination: url).rowText() }
                if let url = Self.privacyURL { Link("Privacy Policy", destination: url).rowText() }
                if let url = PaywallView.termsURL { Link("Terms of Use", destination: url).rowText() }
                NavigationLink("Licenses", value: SettingsPage.licenses)
                    .rowText()
            } footer: {
                // The one line where the app speaks as its maker (D101).
                Text("Made with care by the Maru team.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The version and the build, for example "1.0 (12)".
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// The license of GRDB.swift, the one third-party dependency. `docs/third-party-licenses.md` holds the same text.
/// A license text stays in English.
struct LicensesView: View {
    var body: some View {
        List {
            Section {
                Text(verbatim: Self.grdb)
                    .font(.footnote)
                    .textSelection(.enabled)
            } header: {
                Text(verbatim: "GRDB.swift")
            }
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let grdb = """
        Copyright (C) 2015-2025 Gwendal Roué

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
}

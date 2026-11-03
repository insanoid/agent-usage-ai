#if DEBUG
    import SwiftUI

    struct WidgetPreview: View {
        let size: String
        let state: String
        var body: some View {
            let medium = size == "medium"
            NavigationStack {
                VStack(spacing: 24) {
                    WidgetContent(cache: SampleUsage.cache(state: state), selections: [
                        WidgetSelection(
                            id: state == "missing-login" ? "claude:personal" : "claude:work",
                            title: state == "missing-login" ? "Claude · Personal" : "Claude · Work"
                        ),
                        WidgetSelection(id: "codex:work", title: "Codex · Work"),
                    ], isMedium: medium)
                        .padding(16)
                        .frame(width: medium ? 344 : 158, height: 162)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    Text("\(size.capitalized) widget · fictional data").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Widget Preview")
            }
        }
    }
#endif

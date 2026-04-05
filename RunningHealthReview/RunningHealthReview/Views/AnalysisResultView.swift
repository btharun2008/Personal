import SwiftUI

struct AnalysisResultView: View {
    let title: String
    let analysis: String
    let isLoading: Bool
    let error: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Analysing your training…").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if let error {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.largeTitle).foregroundStyle(.red)
                            Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        MarkdownText(analysis)
                            .padding()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                if !analysis.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: analysis)
                    }
                }
            }
        }
    }
}

import SwiftUI

private struct IntroPage: Identifiable {
    let id: Int
    let title: String
    let text: String
    let photo: URL
}

// Free-to-use photos from Wikimedia Commons (CC0 / public domain); source pages are listed in README.md.
private let pages = [
    IntroPage(id: 0, title: "Timed recording", text: "Pick a length. Recording stops on its own.",
              photo: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Don_Quijote_de_la_Mancha_en_el_Teatro_Teresa_Carre%C3%B1o%2C_Caracas%2C_Venezuela_3.jpg/1280px-Don_Quijote_de_la_Mancha_en_el_Teatro_Teresa_Carre%C3%B1o%2C_Caracas%2C_Venezuela_3.jpg")!),
    IntroPage(id: 1, title: "Countdown", text: "Get in position before it starts.",
              photo: URL(string: "https://upload.wikimedia.org/wikipedia/commons/b/b3/Marthe_Weijers%2C_hiphop_dancer.jpg")!),
    IntroPage(id: 2, title: "Review and save", text: "Replay takes and save them to Photos.",
              photo: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1c/Illstyle_%26_Peace_Productions_hip_hop_show_in_Donetsk%2C_April_4%2C_2013_%288639988872%29.jpg/1280px-Illstyle_%26_Peace_Productions_hip_hop_show_in_Donetsk%2C_April_4%2C_2013_%288639988872%29.jpg")!),
]

struct IntroView: View {
    let onFinish: () -> Void
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                ForEach(pages) { page in
                    VStack(spacing: 16) {
                        RemotePhoto(url: page.photo)
                        Text(page.title).font(.app(.title2))
                        Text(page.text)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        Spacer(minLength: 40)
                    }
                    .padding()
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if selection < pages.count - 1 {
                    withAnimation { selection += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(selection < pages.count - 1 ? "Next" : "Get started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button("Skip", action: onFinish).padding()
        }
        .font(.app())
        .tint(.orange)
    }
}

private struct RemotePhoto: View {
    let url: URL
    @State private var attempt = 0

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: .easeIn)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark").font(.title)
                            Button("Try again") { attempt += 1 }.buttonStyle(.bordered)
                        }
                        .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                // AsyncImage has no reload API; a new identity starts a fresh request.
                .id(attempt)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityHidden(true)
    }
}

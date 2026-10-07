import SwiftUI

struct SwitcherSearch: View {
    @ObservedObject var model: SwitcherModel
    var body: some View {
        Button { model.searching = true } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                Text(model.query.isEmpty ? (model.searching ? "Type to search…" : "Search windows & tabs · /") : model.query)
                    .lineLimit(1)
                Spacer()
                if model.searching { Text("Enter to open · Esc to close").font(.system(size: 10)) }
            }.font(.system(size: 12)).foregroundStyle(model.searching ? .primary : .secondary)
                .padding(10).background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
        if model.windows.isEmpty { Text("No matching windows or tabs").font(.caption).foregroundStyle(.secondary) }
        if !model.browserStatus.isEmpty { Text(model.browserStatus).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2) }
    }
}

extension SwitcherModel {
    func filterResults() {
        let tokens = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).split(whereSeparator: \.isWhitespace).map(String.init)
        let previous = windows.indices.contains(selected) ? windows[selected].id : nil
        windows = sourceWindows.enumerated().compactMap { offset, entry -> (Int, Int, WindowEntry)? in
            let haystack = (entry.appName + " " + entry.title + " " + (entry.browserTab?.url ?? "")).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            var score = 0
            for token in tokens {
                if haystack.contains(token) { score += haystack.hasPrefix(token) ? 100 : 50 }
                else {
                    var chars = token.makeIterator()
                    var next = chars.next()
                    for char in haystack where next != nil { if char == next { next = chars.next() } }
                    guard next == nil else { return nil }
                    score += 1
                }
            }
            return (score, offset, entry)
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 > $1.0 }.map { $0.2 }
        selected = windows.firstIndex(where: { $0.id == previous }) ?? 0
    }
}

import SwiftUI

struct SpendingEntryList: View {
    let entries: [ExpenseEntry]
    let edit: (ExpenseEntry) -> Void
    let delete: (ExpenseEntry) -> Void
    @ScaledMetric private var rowHeight = ExpenseConstants.spendingEntryRowHeight

    var body: some View {
        List {
            ForEach(entries) { entry in
                Button {
                    edit(entry)
                } label: {
                    HStack {
                        Text(IncomeFormat.shortDate(entry.spentOn))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(IncomeFormat.currency(entry.amount))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .frame(height: rowHeight)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                .listRowBackground(Color.clear)
                .listRowSeparator(entry.id == entries.last?.id ? .hidden : .visible, edges: .bottom)
                .listRowSeparator(.hidden, edges: .top)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Apagar", systemImage: "trash", role: .destructive) {
                        delete(entry)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .environment(\.defaultMinListRowHeight, rowHeight)
        .frame(height: rowHeight * CGFloat(entries.count))
        .padding(.vertical, 4)
        .clipShape(.rect(cornerRadius: 26))
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

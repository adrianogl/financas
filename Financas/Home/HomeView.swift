import Charts
import SwiftUI

struct HomeView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(AccountManager.self) private var account
    @Environment(IncomeStore.self) private var incomeStore
    @Binding var selectedTab: AppTab
    @State private var confirmsSignOut = false

    var body: some View {
        @Bindable var incomeStore = incomeStore
        let month = incomeStore.selectedMonth
        let summary = HomeMonthSummary.make(month: month, snapshot: incomeStore.snapshot, today: incomeStore.today)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    MonthPicker(month: $incomeStore.selectedMonth)
                    balanceCard(summary)
                    IncomeSummaryCard {
                        selectedTab = .incomes
                    }
                    entriesCard(summary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .readableWidth(LayoutConstants.contentWidth)
            }
            .background(AppBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Conta", systemImage: "person.crop.circle") {
                        Button("Bloquear", systemImage: "lock") {
                            lockManager.lock()
                        }
                        Button("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            confirmsSignOut = true
                        }
                    }
                }
            }
            .confirmationDialog("Sair da conta?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                Button("Sair", role: .destructive) {
                    Task { await account.signOut() }
                }
            } message: {
                Text("O PIN deste aparelho será apagado. Para voltar, entre com seu e-mail e senha.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            CollapsingAppLogo(markSize: 44, isVisible: lockManager.isUnlocked)
                .padding(.bottom, 10)
            Text(Greeting.text(hour: Calendar.current.component(.hour, from: .now), name: account.userName ?? ""))
                .font(.largeTitle.bold())
            Text(Greeting.dateText(for: .now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func balanceCard(_ summary: HomeMonthSummary) -> some View {
        let domain = summary.chartDomain
        return VStack(alignment: .leading, spacing: 6) {
            Text("Saldo até \(IncomeFormat.monthName(summary.month))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IncomeFormat.currency(summary.balance))
                .font(.system(size: 34, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Chart(summary.points) { point in
                AreaMark(
                    x: .value("Dia", point.day),
                    yStart: .value("Base", domain.lowerBound),
                    yEnd: .value("Saldo", point.balance)
                )
                .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("Dia", point.day), y: .value("Saldo", point.balance))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 1...summary.month.dayCount)
            .chartYScale(domain: domain)
            .frame(height: 96)
            .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .animation(.smooth, value: summary)
    }

    private func entriesCard(_ summary: HomeMonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lançamentos de \(IncomeFormat.monthName(summary.month))")
                .font(.headline)
                .padding(.bottom, 6)
            if summary.entries.isEmpty {
                Text("Nenhum lançamento em \(IncomeFormat.monthName(summary.month)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            ForEach(summary.entries) { entry in
                TransactionRow(entry: entry)
                if entry.id != summary.entries.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

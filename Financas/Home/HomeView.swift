import Charts
import SwiftUI

struct HomeView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(AccountManager.self) private var account
    @State private var confirmsSignOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    balanceCard
                    transactionsCard
                    Text("Valores de exemplo")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
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

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(HomeConstants.sampleMonthLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(HomeConstants.sampleBalance, format: .currency(code: HomeConstants.currencyCode))
                .font(.system(size: 34, weight: .semibold))
                .monospacedDigit()
            Chart(HomeConstants.balancePoints) { point in
                AreaMark(
                    x: .value("Dia", point.day),
                    yStart: .value("Base", HomeConstants.balanceFloor),
                    yEnd: .value("Saldo", point.balance)
                )
                .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)

                LineMark(x: .value("Dia", point.day), y: .value("Saldo", point.balance))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: HomeConstants.balanceFloor...HomeConstants.balanceCeiling)
            .frame(height: 96)
            .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos lançamentos")
                .font(.headline)
                .padding(.bottom, 6)
            ForEach(HomeConstants.sampleTransactions) { transaction in
                TransactionRow(transaction: transaction)
                if transaction.id != HomeConstants.sampleTransactions.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

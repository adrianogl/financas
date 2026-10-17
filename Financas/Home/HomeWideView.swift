import SwiftUI

struct HomeWideView: View {
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(ExpenseStore.self) private var expenseStore
    @Environment(AppNavigation.self) private var navigation
    @State private var width: CGFloat = 0
    @State private var receiving: IncomeOccurrence?
    @State private var editingIncome: IncomeDraft?
    @State private var paying: ExpenseSheetTarget?
    @State private var editingExpense: ExpenseDraft?
    @State private var detail: DetailRoute?

    var body: some View {
        let summary = HomeMonthSummary.make(month: incomeStore.selectedMonth, snapshot: incomeStore.snapshot, expenses: expenseStore.snapshot, today: incomeStore.today)
        let stats = HomeStats(incomes: incomeStore, expenses: expenseStore)
        let arrangement = HomeArrangement.make(mode: navigation.mode, contentWidth: width)

        ScrollView {
            VStack(alignment: .leading, spacing: HomeConstants.cardSpacing) {
                top(arrangement)
                switch arrangement {
                case .twoColumns:
                    twoColumns(summary, stats: stats)
                case .threeColumns:
                    threeColumns(summary, stats: stats)
                case .stacked:
                    stacked(summary, stats: stats)
                }
            }
            .padding(.horizontal, LayoutConstants.listDetailMargin)
            .padding(.top, LayoutConstants.sectionHeaderTopPadding)
            .padding(.bottom, 32)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .incomeReceiptFlow(receiving: $receiving, editing: $editingIncome)
        .expenseFlow(paying: $paying, editing: $editingExpense)
        .sheet(isPresented: isDetailPresented) {
            if let detail {
                DetailSheet(route: detail)
            }
        }
    }

    @ViewBuilder
    private func top(_ arrangement: HomeArrangement) -> some View {
        @Bindable var incomeStore = incomeStore
        if arrangement == .stacked {
            HomeHeader()
            MonthPicker(month: $incomeStore.selectedMonth)
        } else {
            HStack(alignment: .bottom, spacing: HomeConstants.cardSpacing) {
                HomeHeader()
                Spacer(minLength: HomeConstants.cardSpacing)
                MonthPicker(month: $incomeStore.selectedMonth)
                    .frame(width: HomeConstants.monthPickerWidth)
            }
        }
    }

    private func twoColumns(_ summary: HomeMonthSummary, stats: HomeStats) -> some View {
        let available = max(width - LayoutConstants.listDetailMargin * 2 - HomeConstants.cardSpacing, 0)
        return Group {
            HStack(alignment: .top, spacing: HomeConstants.cardSpacing) {
                BalanceChartCard(summary: summary, chartHeight: HomeConstants.wideChartHeight, showsDayScale: true)
                    .frame(width: available * HomeConstants.chartColumnShare)
                VStack(spacing: HomeConstants.statSpacing) {
                    HomeStatCard(stats.receivable)
                    HomeStatCard(stats.payable)
                    overdueCard(stats)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            lists
        }
    }

    private func threeColumns(_ summary: HomeMonthSummary, stats: HomeStats) -> some View {
        Group {
            HStack(spacing: HomeConstants.statSpacing) {
                HomeStatCard(stats.balance)
                HomeStatCard(stats.receivable)
                HomeStatCard(stats.payable)
                overdueCard(stats)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: HomeConstants.cardSpacing) {
                incomeList
                expenseList
                BalanceChartCard(summary: summary, chartHeight: HomeConstants.wideChartHeight, showsDayScale: true, title: "Saldo dia a dia")
            }
        }
    }

    private func stacked(_ summary: HomeMonthSummary, stats: HomeStats) -> some View {
        Group {
            BalanceChartCard(summary: summary, chartHeight: HomeConstants.portraitChartHeight, showsDayScale: true)
            HStack(spacing: HomeConstants.statSpacing) {
                HomeStatCard(stats.receivable)
                HomeStatCard(stats.payable)
                overdueCard(stats)
            }
            .fixedSize(horizontal: false, vertical: true)
            lists
        }
    }

    private var lists: some View {
        HStack(alignment: .top, spacing: HomeConstants.cardSpacing) {
            incomeList
            expenseList
        }
    }

    private var incomeList: some View {
        HomeIncomeListCard(create: createIncome, receive: { receiving = $0 }, open: openDetail)
    }

    private var expenseList: some View {
        HomeExpenseListCard(create: createExpense, pay: { paying = ExpenseSheetTarget(occurrence: $0, mode: .payment) }, open: openDetail)
    }

    private func overdueCard(_ stats: HomeStats) -> some View {
        HomeStatCard(stats.overdue) {
            navigation.section = .overdue
        }
    }

    private func openDetail(_ route: DetailRoute) {
        if HomeArrangement.opensSection(mode: navigation.mode, contentWidth: width) {
            navigation.open(route)
        } else {
            detail = route
        }
    }

    private func createIncome() {
        editingIncome = IncomeDraft(today: incomeStore.today, kind: incomeStore.settings.orderedEnabledKinds.first ?? .fixed)
    }

    private func createExpense() {
        editingExpense = ExpenseDraft(today: incomeStore.today)
    }

    private var isDetailPresented: Binding<Bool> {
        Binding(get: { detail != nil }, set: { if !$0 { detail = nil } })
    }
}

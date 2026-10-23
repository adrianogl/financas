import SwiftUI

struct CardsView: View {
    @Environment(CardStore.self) private var store
    @Environment(AppNavigation.self) private var navigation
    @State private var isReviewing = false

    var body: some View {
        let mode = navigation.mode

        NavigationStack {
            Group {
                if mode == .compact {
                    ScrollView {
                        content(mode)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                            .readableWidth(LayoutConstants.contentWidth)
                    }
                    .refreshable { await store.refresh() }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                            .padding(.horizontal, LayoutConstants.listDetailMargin)
                            .padding(.top, LayoutConstants.sectionHeaderTopPadding)
                        ScrollView {
                            content(mode)
                                .padding(.horizontal, LayoutConstants.listDetailMargin)
                                .padding(.bottom, 32)
                        }
                        .refreshable { await store.refresh() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
            .navigationTitle("Cartões")
            .toolbar(mode == .compact ? .automatic : .hidden, for: .navigationBar)
            .sheet(isPresented: $isReviewing) {
                RecurrenceReviewSheet()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text("Cartões")
                .font(.largeTitle.bold())
            Spacer(minLength: 8)
            if !store.snapshot.connections.isEmpty {
                Text(CardFormat.syncText(store.oldestSync, now: .now))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: LayoutConstants.sectionHeaderMinHeight)
    }

    @ViewBuilder
    private func content(_ mode: LayoutMode) -> some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Tentar de novo") {
                    Task { await store.load() }
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        case .loaded:
            if store.snapshot.connections.isEmpty {
                CardsEmptyState(onConnect: openConnections)
                    .padding(.top, 40)
            } else {
                dashboard(mode)
            }
        }
    }

    @ViewBuilder
    private func dashboard(_ mode: LayoutMode) -> some View {
        switch mode {
        case .compact:
            VStack(alignment: .leading, spacing: 16) {
                notices
                summary(chartHeight: CardConstants.chartHeightCompact)
                endingSection
                fixedSection(limit: CardConstants.fixedPreviewCompact)
            }
        case .regularLandscape:
            VStack(alignment: .leading, spacing: 16) {
                warnings
                HStack(alignment: .top, spacing: LayoutConstants.listDetailSpacing) {
                    VStack(alignment: .leading, spacing: 16) {
                        review
                        summary(chartHeight: CardConstants.chartHeightLandscape)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 16) {
                        endingSection
                        fixedSection(limit: CardConstants.fixedPreviewLandscape)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        case .regularPortrait:
            VStack(alignment: .leading, spacing: 16) {
                notices
                summary(chartHeight: CardConstants.chartHeightPortrait)
                HStack(alignment: .top, spacing: LayoutConstants.listDetailSpacing) {
                    VStack(alignment: .leading, spacing: 16) {
                        endingSection
                        otherInstallmentsSection
                    }
                    .frame(maxWidth: .infinity)
                    fixedSection(limit: CardConstants.fixedPreviewPortrait)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var notices: some View {
        warnings
        review
    }

    @ViewBuilder
    private var warnings: some View {
        let now = Date.now
        ForEach(store.snapshot.connections) { connection in
            if let text = CardFormat.connectionWarning(connection, nickname: store.nickname(for: connection), now: now) {
                CardConnectionWarning(text: text, action: openConnections)
            }
        }
        if let message = store.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.warning)
                .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var review: some View {
        let candidates = store.candidates
        if !candidates.isEmpty {
            RecurrenceReviewBanner(
                count: candidates.count,
                names: candidates.prefix(CardConstants.reviewPreviewCount).map(\.name)
            ) {
                isReviewing = true
            }
        }
    }

    private func summary(chartHeight: CGFloat) -> some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 16) {
            CardFilterBar(filter: $store.filter, accounts: store.accounts)
            CardsPanelCard(months: store.months, chartHeight: chartHeight)
        }
    }

    private var endingSection: some View {
        let count = store.plans.count
        return VStack(alignment: .leading, spacing: 8) {
            CardSectionHeader(title: "Terminando", linkTitle: count > 0 ? "Ver parcelas (\(count))" : nil) {
                CardInstallmentsView()
            }
            CardEndingList(plans: store.ending)
        }
    }

    @ViewBuilder
    private var otherInstallmentsSection: some View {
        let ending = Set(store.ending)
        let others = store.plans
            .filter { !ending.contains($0) }
            .sorted { ($0.lastMonth, $0.name) < ($1.lastMonth, $1.name) }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CardSectionHeader(title: "Outras parcelas", linkTitle: nil) {
                    EmptyView()
                }
                CardInstallmentList(plans: Array(others.prefix(CardConstants.otherInstallmentsPreview)))
            }
        }
    }

    private func fixedSection(limit: Int) -> some View {
        let charges = store.fixedCharges.sorted { $0.amount > $1.amount }
        return VStack(alignment: .leading, spacing: 8) {
            CardSectionHeader(title: "Fixos", linkTitle: charges.isEmpty ? nil : "Ver todos (\(charges.count))") {
                CardFixedChargesView()
            }
            CardFixedList(charges: Array(charges.prefix(limit)))
        }
    }

    private func openConnections() {}
}

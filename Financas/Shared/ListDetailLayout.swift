import SwiftUI

struct ListDetailLayout<List: View>: View {
    @Environment(AppNavigation.self) private var navigation
    @State private var width: CGFloat?
    let section: AppTab
    let title: String
    let add: SectionAddAction?
    let routes: [DetailRoute]
    let openRoutes: [DetailRoute]
    let isLoaded: Bool
    let emptyText: String?
    @ViewBuilder let list: (ListDetailContext) -> List

    var body: some View {
        Group {
            if let presentation {
                content(presentation)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .navigationTitle(title)
        .toolbar(presentation == .push ? .automatic : .hidden, for: .navigationBar)
        .toolbar {
            if presentation == .push, let add {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(add.title, systemImage: "plus", action: add.action)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: presentation, initial: true) { old, new in
            if let new, old != new {
                navigation.presentationChanged(from: old, to: new, in: section)
            }
            refresh()
        }
        .onChange(of: routes) { refresh() }
        .onChange(of: openRoutes) { refresh() }
        .onChange(of: isLoaded) { refresh() }
        .onChange(of: navigation.pendingSelection) { refresh() }
        .sheet(isPresented: isSheetPresented) {
            if let route = navigation.selection(for: section) {
                DetailSheet(route: route)
            }
        }
    }

    private var presentation: DetailPresentation? {
        if navigation.mode == .compact { return .push }
        return width.map { DetailPresentation.make(mode: navigation.mode, contentWidth: $0) }
    }

    @ViewBuilder
    private func content(_ presentation: DetailPresentation) -> some View {
        let selection = navigation.selection(for: section)
        let context = ListDetailContext(section: section, presentation: presentation, selection: selection)
        switch presentation {
        case .push:
            ScrollView {
                listColumn(context)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .readableWidth(LayoutConstants.contentWidth)
            }
        case .sheet, .panel:
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: title, add: add)
                    .padding(.horizontal, LayoutConstants.listDetailMargin)
                    .padding(.top, LayoutConstants.sectionHeaderTopPadding)
                if presentation == .panel, selection != nil || emptyText != nil {
                    panel(context, selection: selection)
                } else {
                    ScrollView {
                        listColumn(context)
                            .padding(.horizontal, LayoutConstants.listDetailMargin)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    private func panel(_ context: ListDetailContext, selection: DetailRoute?) -> some View {
        let margin = LayoutConstants.listDetailMargin
        let gap = LayoutConstants.listDetailSpacing / 2
        let available = (width ?? 0) - margin * 2 - LayoutConstants.listDetailSpacing
        let listWidth = max(available / (1 + LayoutConstants.detailPanelRatio), 0)

        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                listColumn(context)
                    .padding(.leading, margin)
                    .padding(.trailing, gap)
                    .padding(.bottom, 32)
            }
            .frame(width: listWidth + margin + gap)
            ScrollView {
                detailCard(selection)
                    .padding(.leading, gap)
                    .padding(.trailing, margin)
                    .padding(.bottom, 32)
            }
        }
    }

    private func listColumn(_ context: ListDetailContext) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            list(context)
        }
    }

    private func detailCard(_ selection: DetailRoute?) -> some View {
        Group {
            if let selection {
                DetailRouteView(route: selection)
                    .environment(\.isDetailPanel, true)
                    .id(selection)
            } else if let emptyText {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(DetailConstants.panelPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private var isSheetPresented: Binding<Bool> {
        Binding(
            get: { navigation.isSheetPresented(in: section) },
            set: { if !$0 { navigation.dismissSheet(in: section) } }
        )
    }

    private func refresh() {
        guard let presentation else { return }
        if let route = navigation.takeSelection(for: section) {
            navigation.select(route, in: section, presentation: presentation)
        }
        if presentation == .panel {
            navigation.applyDefaultSelection(routes: routes, openRoutes: openRoutes, isLoaded: isLoaded, in: section)
        }
    }
}

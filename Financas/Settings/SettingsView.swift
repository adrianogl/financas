import SwiftUI

struct SettingsView: View {
    @Environment(IncomeStore.self) private var store
    @Environment(ReminderScheduler.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Group {
                if store.loadState == .loaded {
                    form
                } else {
                    ScrollView {
                        IncomeLoadContent { EmptyView() }
                            .padding(20)
                    }
                }
            }
            .background(AppBackground())
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.isSavingSettings {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .task { await refreshAuthorization() }
        }
    }

    private var form: some View {
        Form {
            Section {
                ForEach(IncomeFormConstants.kinds, id: \.self) { kind in
                    Toggle(kind.title, isOn: kindBinding(kind))
                        .disabled(store.settings.enabledKinds.contains(kind) && !store.settings.canDisable(kind))
                }
            } header: {
                Text("Tipos de receita")
            } footer: {
                Text("Só os tipos ligados aparecem ao cadastrar uma receita. Pelo menos um precisa ficar ligado.")
            }

            Section {
                Picker("Regra", selection: ruleBinding) {
                    ForEach(NonBusinessDayRule.allCases, id: \.self) { rule in
                        Text(rule.title).tag(rule)
                    }
                }
            } header: {
                Text("Dia não útil")
            } footer: {
                Text(NonBusinessDayExample.text(rule: store.settings.nonBusinessDay))
            }

            Section {
                ForEach(ReminderSlot.allCases, id: \.self) { slot in
                    ReminderSettingRow(title: slot.title, isOn: enabledBinding(slot), time: timeBinding(slot))
                }
            } header: {
                Text("Avisos")
            } footer: {
                if notificationsDenied {
                    Text("As notificações estão desligadas nos Ajustes do iPhone.")
                }
            }

            Section {
                LabeledContent("Versão", value: AppVersion.installed.text())
            } footer: {
                Text("Número da versão, commit e data em que o app foi gerado.")
            }

            if let message = store.settingsErrorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func kindBinding(_ kind: IncomeKind) -> Binding<Bool> {
        Binding {
            store.settings.enabledKinds.contains(kind)
        } set: { isOn in
            var settings = store.settings
            settings.enabledKinds = isOn
                ? IncomeFormConstants.kinds.filter { settings.enabledKinds.contains($0) || $0 == kind }
                : settings.orderedEnabledKinds.filter { $0 != kind }
            save(settings)
        }
    }

    private var ruleBinding: Binding<NonBusinessDayRule> {
        Binding {
            store.settings.nonBusinessDay
        } set: { rule in
            var settings = store.settings
            settings.nonBusinessDay = rule
            save(settings)
        }
    }

    private func enabledBinding(_ slot: ReminderSlot) -> Binding<Bool> {
        Binding {
            store.settings[keyPath: slot.enabled]
        } set: { isOn in
            var settings = store.settings
            settings[keyPath: slot.enabled] = isOn
            save(settings, asksPermission: true)
        }
    }

    private func timeBinding(_ slot: ReminderSlot) -> Binding<Date> {
        Binding {
            store.settings[keyPath: slot.time].date()
        } set: { date in
            var settings = store.settings
            settings[keyPath: slot.time] = ReminderTime(date: date)
            save(settings, asksPermission: true)
        }
    }

    private func save(_ settings: AccountSettings, asksPermission: Bool = false) {
        store.updateSettings(settings)
        guard asksPermission else { return }
        Task {
            await reminders.requestPermissionFromSettings()
            await refreshAuthorization()
        }
    }

    private func refreshAuthorization() async {
        notificationsDenied = await reminders.authorization() == .denied
    }
}

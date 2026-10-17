import SwiftUI

struct ReminderSettingRow: View {
    let title: String
    @Binding var isOn: Bool
    @Binding var time: Date

    var body: some View {
        Toggle(title, isOn: $isOn)
        if isOn {
            DatePicker("Horário", selection: $time, displayedComponents: .hourAndMinute)
                .padding(.leading, 16)
        }
    }
}

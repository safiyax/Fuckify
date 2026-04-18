import SwiftUI
import SQLiteData

struct PartnerAttributeEditField: View {
    let attribute: SQLPartnerAttributeType
    @Binding var value: String?

    var body: some View {
        switch attribute.parsedFieldType {
        case .text:
            HStack {
                Label(attribute.name, systemImage: attribute.icon)
                TextField("", text: Binding(
                    get: { value ?? "" },
                    set: { value = $0 }
                ))
                .multilineTextAlignment(.trailing)
            }

        case .boolean:
            Toggle(isOn: Binding(
                get: { value == "true" },
                set: { value = $0 ? "true" : "false" }
            )) {
                Label(attribute.name, systemImage: attribute.icon)
            }

        case .date:
            let hasDate = value != nil && !(value?.isEmpty ?? true)

            Toggle(isOn: Binding(
                get: { hasDate },
                set: { isOn in
                    if isOn {
                        value = ISO8601DateFormatter().string(from: Date())
                    } else {
                        value = nil
                    }
                }
            )) {
                Label(attribute.name, systemImage: attribute.icon)
            }

            if hasDate {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: {
                            if let dateString = value,
                               let date = ISO8601DateFormatter().date(from: dateString) {
                                return date
                            }
                            return Date()
                        },
                        set: { date in
                            value = ISO8601DateFormatter().string(from: date)
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }

        case .enumType:
            let choices = attribute.parsedEnumChoices
            Picker(selection: Binding(
                get: { value ?? "" },
                set: { value = $0 }
            )) {
                Text("Not set").tag("")
                ForEach(choices, id: \.self) { choice in
                    Text(choice).tag(choice)
                }
            } label: {
                Label(attribute.name, systemImage: attribute.icon)
            }
        }
    }
}

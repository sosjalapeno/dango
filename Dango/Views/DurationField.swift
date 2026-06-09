import SwiftUI

struct DurationField<F: Hashable>: View {

    let label: String
    @Binding var value: Int
    let focusValue: F
    var focusedField: FocusState<F>.Binding

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            TextField("", value: $value, format: .number)
                .focused(focusedField, equals: focusValue)
                .frame(width: 50)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    value = max(1, min(180, value))
                }

            Text("min")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }
}

import SwiftUI

/// Step 6 of the signup form — "What are your current goals?" (Figma Goals
/// Screen, node 209:662). One required free-text field, an Optional divider,
/// then two optional fields. No quick-pick chips — just the three text boxes.
struct GoalsStepView: View {
    @Bindable var vm: SignupFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("What are your current goals?")
                .largeTitleStyle()

            VStack(alignment: .leading, spacing: 10) {
                FieldLabel(text: "What are you hoping to get out of this?", required: true)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.surface)
                    if vm.expectations.isEmpty {
                        Text("e.g. Meet people who care about the\nsame social justice programs as I do")
                            .font(.bodyText)
                            .italic()
                            .foregroundStyle(Theme.placeholder)
                            .padding(.horizontal, 17)
                            .padding(.top, 17)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $vm.expectations, axis: .vertical)
                        .font(.bodyText)
                        .lineLimit(3...)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 17)
                }
                .frame(minHeight: 92)
            }

            optionalDivider

            VStack(alignment: .leading, spacing: 24) {
                goalTextField(
                    label: "What is your current role?",
                    placeholder: "e.g. Uni student, barista, between jobs...",
                    text: $vm.occupation
                )
                goalTextField(
                    label: "What do you believe you can bring to a volunteer program team?",
                    placeholder: "e.g. Showing up with good energy!!!",
                    text: $vm.keySkills
                )
            }
        }
    }

    private var optionalDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.divider).frame(height: 1)
            Text("Optional")
                .font(.labelItalic)
                .foregroundStyle(Theme.placeholder)
                .fixedSize()
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
    }

    private func goalTextField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.bodyText)
                        .italic()
                        .foregroundStyle(Theme.placeholder)
                        .padding(.horizontal, 17)
                        .allowsHitTesting(false)
                }
                TextField("", text: text)
                    .font(.bodyText)
                    .padding(.horizontal, 17)
            }
            .frame(height: 54)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

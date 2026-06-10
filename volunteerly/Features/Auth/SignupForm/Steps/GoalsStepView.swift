import SwiftUI

struct GoalsStepView: View {
    @Bindable var vm: SignupFormViewModel

    // Pre-written quick-pick suggestions per question. Tapping a chip fills
    // the field with its text — the user can edit further or tap a different
    // chip to replace.
    private let expectationSuggestions = [
        "Meet new people",
        "Build my skills",
        "Give back to the community",
        "Make a real difference",
        "Find purpose outside of work",
    ]
    private let occupationSuggestions = [
        "Uni student",
        "Working professional",
        "Between jobs",
        "Retired",
        "Stay-at-home parent",
        "Freelancer",
    ]
    private let keySkillsSuggestions = [
        "Positive energy",
        "Strong communication",
        "Hands-on problem solving",
        "Leadership experience",
        "Patience & empathy",
        "Technical skills",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("What are your\ncurrent goals?")
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
                suggestionChips(expectationSuggestions, text: $vm.expectations)
            }

            optionalDivider

            VStack(alignment: .leading, spacing: 24) {
                goalTextField(
                    label: "What is your current role?",
                    placeholder: "e.g. Uni student, barista, between jobs...",
                    text: $vm.occupation,
                    suggestions: occupationSuggestions
                )
                goalTextField(
                    label: "What do you believe you can bring to a volunteer program team?",
                    placeholder: "e.g. Showing up with good energy!!!",
                    text: $vm.keySkills,
                    suggestions: keySkillsSuggestions
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
        text: Binding<String>,
        suggestions: [String]
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
            suggestionChips(suggestions, text: text)
        }
    }

    /// Horizontally-scrolling row of quick-pick chips below a field. Tapping a
    /// chip replaces the field's current text with the chip's label.
    private func suggestionChips(_ suggestions: [String], text: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        text.wrappedValue = suggestion
                    } label: {
                        Text(suggestion)
                            .font(.buttonLabel)
                            .foregroundStyle(Theme.forest)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.forest.opacity(0.08))
                            .overlay(
                                Capsule().stroke(Theme.forest.opacity(0.35), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            // Tiny vertical padding so the stroked capsule isn't clipped.
            .padding(.vertical, 1)
        }
    }
}

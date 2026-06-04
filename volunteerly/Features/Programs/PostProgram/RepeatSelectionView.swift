import SwiftUI

struct RepeatSelectionView: View {
    @Binding var selectedRepeat: String
    @Environment(\.dismiss) var dismiss
    
    let options = ["None", "Daily", "Weekly", "Bi-weekly", "Monthly"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    RadioButton(
                        title: option,
                        isSelected: Binding(
                            get: { selectedRepeat == option },
                            set: { isSelected in
                                if isSelected {
                                    selectedRepeat = option
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        dismiss()
                                    }
                                }
                            }
                        )
                    )
                }
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

struct DateControlView: View {
    let dateString: String
    let hijriString: String
    @Binding var showCalendar: Bool
    @Binding var selectedDate: Date
    @State private var tempDate: Date = Date()

    
    // Actions
    var onNext: () -> Void
    var onPrev: () -> Void
    var onJump: (Date) -> Void
    var isToday: Bool
    var onReturnToToday: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    withAnimation {
                        onPrev()
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Button(action: {
                    showCalendar = true
                }) {
                    VStack(spacing: 4) {
                        Text(dateString)
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(hijriString)
                            .font(.system(.caption, design: .serif))
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                }
                .sheet(isPresented: $showCalendar) {
                    VStack {
                        DatePicker("Select Date", selection: $tempDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding()
                            .onChange(of: tempDate) { newValue in
                                selectedDate = newValue
                                onJump(newValue)
                                showCalendar = false
                            }
                            .onAppear {
                                tempDate = selectedDate
                            }
                    }
                    .presentationDetents([.medium])
                }
                
                Button(action: {
                    withAnimation {
                        onNext()
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.top, 10)
            
            if !isToday {
                Button(action: {
                    withAnimation {
                        onReturnToToday()
                    }
                }) {
                    Text("Return to Today")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                }
                .padding(.top, 10)
            }
        }
    }
}

import SwiftUI

struct WeekNavigatorView: View {
    @Binding var currentWeekOffset: Int
    @ObservedObject var lswService: LSWService
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date())!
    }
    
    private var currentOrgWeek: Int { lswService.orgWeekNumber(for: referenceDate) }
    private var currentOrgYear: Int { lswService.orgYear(for: referenceDate) }
    
    private var currentWeekDates: (start: Date, end: Date) {
        lswService.weekDates(weekNumber: currentOrgWeek, year: currentOrgYear)
    }
    
    private var isOnCurrentWeek: Bool { currentWeekOffset == 0 }
    
    var body: some View {
        HStack(spacing: 0) {
            if !isOnCurrentWeek {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentWeekOffset = 0
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .bold))
                        Text("Current")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(hex: "0EA5E9"))
                    .clipShape(Capsule())
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(width: 70, height: 28)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    withAnimation { currentWeekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textPrimary)
                        .frame(width: 32, height: 32)
                        .background(cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(cardBorder, lineWidth: 1))
                }
                
                VStack(spacing: 2) {
                    Text("Week \(currentOrgWeek)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "0EA5E9"))
                    
                    Text("\(formatShortDate(currentWeekDates.start)) — \(formatShortDate(currentWeekDates.end))")
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                }
                
                Button {
                    withAnimation { currentWeekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textPrimary)
                        .frame(width: 32, height: 32)
                        .background(cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(cardBorder, lineWidth: 1))
                }
            }
            
            Spacer()
            
            Color.clear.frame(width: 70, height: 28)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

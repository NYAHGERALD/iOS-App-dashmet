//
//  DesignSystem.swift
//  MeetingIntelligence
//
//  Enterprise Design System - Colors, Gradients, Styles
//  Supports both Light and Dark modes
//

import SwiftUI

// MARK: - App Colors (Adaptive for Light/Dark Mode)
struct AppColors {
    // Primary Brand Colors (same in both modes)
    static let primary = Color(hex: "6366F1")        // Indigo
    static let primaryDark = Color(hex: "4F46E5")
    static let primaryLight = Color(hex: "818CF8")
    
    // Secondary Colors
    static let secondary = Color(hex: "8B5CF6")      // Purple
    static let accent = Color(hex: "06B6D4")         // Cyan
    
    // Semantic Colors
    static let success = Color(hex: "10B981")        // Emerald
    static let warning = Color(hex: "F59E0B")        // Amber
    static let error = Color(hex: "EF4444")          // Red
    static let info = Color(hex: "3B82F6")           // Blue
    
    // Adaptive Text Colors - Pure black in light mode, pure white in dark mode
    static let textPrimary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? .white : .black
    })
    static let textSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor.white.withAlphaComponent(0.7) 
            : UIColor.black.withAlphaComponent(0.6)
    })
    static let textTertiary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor.white.withAlphaComponent(0.5) 
            : UIColor.black.withAlphaComponent(0.4)
    })
    
    // Adaptive Background Colors
    static let background = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)  // Very dark
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)  // Light gray
    })
    static let surface = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)  // Dark card
            : .white
    })
    static let surfaceSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)  // Slightly lighter dark
            : UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)  // Very light gray
    })
    static let surfaceElevated = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)
            : .white
    })
    static let border = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor.white.withAlphaComponent(0.1) 
            : UIColor.black.withAlphaComponent(0.1)
    })
    
    // Meeting Type Colors (bright colors work in both modes)
    static let meetingStandup = Color(hex: "10B981")
    static let meetingOneOnOne = Color(hex: "6366F1")
    static let meetingTeam = Color(hex: "8B5CF6")
    static let meetingClient = Color(hex: "F59E0B")
    static let meetingInterview = Color(hex: "EC4899")
}

// MARK: - Gradients
struct AppGradients {
    static let primary = LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let primaryVertical = LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let success = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let warning = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Adaptive card gradient - uses clear so background shows through
    static let card = LinearGradient(
        colors: [Color.clear, Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let heroBackground = LinearGradient(
        colors: [
            Color(hex: "6366F1"),
            Color(hex: "8B5CF6"),
            Color(hex: "A855F7")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let meshBackground = MeshGradient(
        width: 3,
        height: 3,
        points: [
            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
            [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
        ],
        colors: [
            Color(hex: "6366F1"), Color(hex: "8B5CF6"), Color(hex: "A855F7"),
            Color(hex: "818CF8"), Color(hex: "6366F1"), Color(hex: "8B5CF6"),
            Color(hex: "4F46E5"), Color(hex: "6366F1"), Color(hex: "818CF8")
        ]
    )
}

// MARK: - Typography
struct AppTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // Custom styles
    static let statNumber = Font.system(size: 32, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 16, weight: .semibold, design: .default)
    static let cardSubtitle = Font.system(size: 14, weight: .regular, design: .default)
}

// MARK: - Spacing
struct AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
struct AppCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 20
    static let full: CGFloat = 999
}

// MARK: - Shadows
struct AppShadows {
    static let small = Shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    static let large = Shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    static let glow = Shadow(color: AppColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
    
    func elevatedCardStyle() -> some View {
        self
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
    
    func glassStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
    }
    
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppGradients.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
            .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
    }
    
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 3)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var trend: String? = nil
    var trendUp: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                
                Spacer()
                
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(trend)
                            .font(AppTypography.caption)
                    }
                    .foregroundColor(trendUp ? AppColors.success : AppColors.error)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background((trendUp ? AppColors.success : AppColors.error).opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            Text(value)
                .font(AppTypography.statNumber)
                .foregroundColor(AppColors.textPrimary)
            
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Dashboard Quick Action Button
struct DashboardQuickAction: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                    .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - Empty State
struct EnterpriseEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(AppGradients.primary)
            
            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(subtitle)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .primaryButtonStyle()
                }
                .frame(width: 200)
            }
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - Skeleton Loading
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: AppCornerRadius.small)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SkeletonView(width: 40, height: 40)
                Spacer()
                SkeletonView(width: 60, height: 20)
            }
            SkeletonView(width: 80, height: 32)
            SkeletonView(width: 120, height: 14)
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

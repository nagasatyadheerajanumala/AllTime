import SwiftUI

struct DiscoveredEventCard: View {
    let event: DiscoveredEvent
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDetail = false

    private let swipeThreshold: CGFloat = 100
    private let mintColor = Color(hex: "5EEAD4")

    var body: some View {
        ZStack {
            // Swipe background indicators
            HStack {
                // Dismiss (left swipe reveals on right)
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.trailing, 24)
            }
            .opacity(offset < -30 ? Double(-offset - 30) / 70 : 0)

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green.opacity(0.8))
                    .padding(.leading, 24)
                Spacer()
            }
            .opacity(offset > 30 ? Double(offset - 30) / 70 : 0)

            // Main card content
            HStack(spacing: 0) {
                // Mint accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(mintColor)
                    .frame(width: 4)
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 6) {
                    // Category chip + Clara label
                    HStack(spacing: 6) {
                        Text("\(event.categoryEmoji) \(event.interestTag ?? event.category ?? "")")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(mintColor.opacity(0.15))
                            .foregroundColor(mintColor)
                            .cornerRadius(8)

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("Clara")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Title
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // Date, time and location
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(event.formattedDate)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(event.formattedTime)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let loc = event.locationName, !loc.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(loc)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(mintColor.opacity(0.2), lineWidth: 1)
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation.width
                    }
                    .onEnded { value in
                        if value.translation.width > swipeThreshold {
                            // Swipe right → accept
                            withAnimation(.spring(response: 0.3)) {
                                offset = 500
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onAccept()
                            }
                        } else if value.translation.width < -swipeThreshold {
                            // Swipe left → dismiss
                            withAnimation(.spring(response: 0.3)) {
                                offset = -500
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDismiss()
                            }
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                showDetail = true
            }
        }
        .sheet(isPresented: $showDetail) {
            DiscoveredEventDetailSheet(event: event, onAccept: {
                showDetail = false
                onAccept()
            }, onDismiss: {
                showDetail = false
                onDismiss()
            })
        }
    }
}

// MARK: - Detail Sheet

struct DiscoveredEventDetailSheet: View {
    let event: DiscoveredEvent
    let onAccept: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let mintColor = Color(hex: "5EEAD4")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Category chip
                    HStack {
                        Text("\(event.categoryEmoji) \(event.interestTag ?? event.category ?? "")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(mintColor.opacity(0.15))
                            .foregroundColor(mintColor)
                            .cornerRadius(10)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("Clara suggestion")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Title
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Date & Time
                    HStack(spacing: 16) {
                        Label(event.formattedDate, systemImage: "calendar")
                        Label(event.formattedTime, systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    // Location
                    if let loc = event.locationName, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Description
                    if let desc = event.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 24)

                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: onDismiss) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("Skip")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }

                        Button(action: onAccept) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add to Calendar")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(mintColor)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .fontWeight(.semibold)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

//
//  ShareEventByIdSheet.swift
//  AllTime
//
//  Wrapper that loads event details by ID, then presents ShareEventSheet.
//  Used when we only have an event ID (e.g. after accepting a discovered event).
//

import SwiftUI

struct ShareEventByIdSheet: View {
    let eventId: Int64

    @State private var eventDetails: EventDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let details = eventDetails {
                ShareEventSheet(eventDetails: details)
            } else if isLoading {
                NavigationStack {
                    ZStack {
                        DesignSystem.Colors.background.ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading event...")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .navigationTitle("Share Event")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .font(.system(size: 22))
                            }
                        }
                    }
                }
            } else {
                NavigationStack {
                    ZStack {
                        DesignSystem.Colors.background.ignoresSafeArea()
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text(errorMessage ?? "Failed to load event")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Button("Dismiss") { dismiss() }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.violet)
                                .padding(.top, 4)
                        }
                    }
                    .navigationTitle("Share Event")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .font(.system(size: 22))
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadEvent()
        }
    }

    private func loadEvent() async {
        isLoading = true
        do {
            eventDetails = try await APIService.shared.getEventDetails(eventId: eventId)
        } catch {
            print("ShareEventByIdSheet: Failed to load event \(eventId): \(error)")
            errorMessage = "Could not load event details"
        }
        isLoading = false
    }
}

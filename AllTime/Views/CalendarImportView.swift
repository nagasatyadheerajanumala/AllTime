import SwiftUI
import PhotosUI

/// View for importing calendar events from a screenshot
/// Allows users to upload a photo of their Outlook/Google calendar
struct CalendarImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CalendarImportViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Image picker / preview
                        imageSection

                        // Processing status
                        if viewModel.isProcessing {
                            processingSection
                        }

                        // Extracted events
                        if !viewModel.extractedEvents.isEmpty {
                            extractedEventsSection
                        }

                        // Error message
                        if let error = viewModel.errorMessage {
                            errorSection(error)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding()
                }

                // Bottom action button
                VStack {
                    Spacer()
                    bottomActionButton
                }
            }
            .navigationTitle("Import Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                CalendarImagePicker(image: $viewModel.selectedImage, sourceType: viewModel.imageSourceType)
            }
            .confirmationDialog("Choose Photo Source", isPresented: $viewModel.showingSourcePicker) {
                if viewModel.isCameraAvailable {
                    Button("Take Photo") {
                        viewModel.requestCameraAccess()
                    }
                }
                Button("Choose from Library") {
                    viewModel.requestPhotoLibraryAccess()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Events Imported!", isPresented: $viewModel.showingSuccessAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(viewModel.savedCount) events have been added to your calendar.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary)

            Text("Import from Screenshot")
                .font(.title2.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Take a photo or upload a screenshot of your Outlook, Google, or Apple calendar. We'll extract the events and add them to your calendar.")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }

    // MARK: - Image Section

    private var imageSection: some View {
        VStack(spacing: 16) {
            if let image = viewModel.selectedImage {
                // Show selected image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 2)
                    )

                Button(action: { viewModel.showingSourcePicker = true }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Change Image")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            } else {
                // Empty state - prompt to upload
                Button(action: { viewModel.showingSourcePicker = true }) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.Colors.primary)

                        Text("Tap to upload calendar screenshot")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text("Supports JPEG, PNG, HEIC")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Processing Section

    private var processingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                .scaleEffect(1.2)

            Text("Analyzing calendar...")
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Using AI to extract events from your screenshot")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Extracted Events Section

    private var extractedEventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with select all toggle
            HStack {
                Text("Extracted Events")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Text("\(viewModel.selectedEvents.count)/\(viewModel.extractedEvents.count)")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Button(action: {
                    if viewModel.allEventsSelected {
                        viewModel.deselectAllEvents()
                    } else {
                        viewModel.selectAllEvents()
                    }
                }) {
                    Text(viewModel.allEventsSelected ? "Deselect All" : "Select All")
                        .font(.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }

            // Instructions
            Text("Tap events to select which ones to import")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            ForEach(viewModel.extractedEvents) { event in
                ExtractedEventRow(
                    event: event,
                    isSelected: viewModel.selectedEvents.contains(event.id),
                    onToggle: { viewModel.toggleEventSelection(event) }
                )
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DesignSystem.Colors.warningYellow)

            Text(message)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.warningYellow.opacity(0.1))
        )
    }

    // MARK: - Bottom Action Button

    private var bottomActionButton: some View {
        VStack(spacing: 0) {
            Divider()

            Group {
                if viewModel.selectedImage != nil && viewModel.extractedEvents.isEmpty && !viewModel.isProcessing {
                    // Process button
                    Button(action: { viewModel.processImage() }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Extract Events")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(DesignSystem.Colors.primary)
                        )
                    }
                    .disabled(viewModel.isProcessing)
                } else if !viewModel.extractedEvents.isEmpty {
                    // Import button
                    Button(action: { viewModel.importSelectedEvents() }) {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                if viewModel.selectedEvents.isEmpty {
                                    Text("Select Events to Import")
                                } else {
                                    Text("Import \(viewModel.selectedEvents.count) Event\(viewModel.selectedEvents.count == 1 ? "" : "s")")
                                }
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(viewModel.selectedEvents.isEmpty ? Color.gray : DesignSystem.Colors.primary)
                        )
                    }
                    .disabled(viewModel.selectedEvents.isEmpty || viewModel.isSaving)
                }
            }
            .padding()
            .background(DesignSystem.Colors.background)
        }
    }
}

// MARK: - Extracted Event Row

struct ExtractedEventRow: View {
    let event: ExtractedEventDTO
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.tertiaryText)

                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(event.formattedDate)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        Text("•")
                            .foregroundColor(DesignSystem.Colors.tertiaryText)

                        Text(event.timeRange)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? DesignSystem.Colors.primary : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Calendar Image Picker (supports camera)

struct CalendarImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CalendarImagePicker

        init(_ parent: CalendarImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarImportView()
}

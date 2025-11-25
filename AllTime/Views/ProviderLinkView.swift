import SwiftUI

struct ProviderLinkView: View {
    @Binding var selectedProvider: String
    @Environment(\.dismiss) private var dismiss
    @State private var authCode = ""
    @State private var isLinking = false
    @State private var errorMessage: String?
    
    private let providers = [
        ("google", "Google Calendar", "g.circle.fill", Color.red),
        ("microsoft", "Microsoft Outlook", "m.circle.fill", Color.blue),
        ("apple", "Apple Calendar", "applelogo", Color.gray)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Provider Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Provider")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
                        ForEach(providers, id: \.0) { provider in
                            ProviderSelectionCard(
                                id: provider.0,
                                name: provider.1,
                                icon: provider.2,
                                color: provider.3,
                                isSelected: selectedProvider == provider.0
                            ) {
                                selectedProvider = provider.0
                            }
                        }
                    }
                }
                
                if !selectedProvider.isEmpty {
                    // Auth Code Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Authorization Code")
                            .font(.headline)
                        
                        TextField("Enter authorization code", text: $authCode)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("Get this code from your \(providers.first { $0.0 == selectedProvider }?.1 ?? "provider") account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Link Button
                    Button(action: linkProvider) {
                        HStack {
                            if isLinking {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLinking ? "Linking..." : "Link Provider")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedProvider.isEmpty || authCode.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(selectedProvider.isEmpty || authCode.isEmpty || isLinking)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func linkProvider() {
        // This would implement the actual provider linking
        isLinking = true
        errorMessage = nil
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLinking = false
            // For demo purposes, just dismiss
            dismiss()
        }
    }
}

struct ProviderSelectionCard: View {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Connect your \(name) account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProviderLinkView(selectedProvider: .constant(""))
}


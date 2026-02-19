//
//  LocationInfoView.swift
//  CarCardCollector
//
//  Location information form with location name field
//

import SwiftUI

struct LocationInfoView: View {
    let capturedImage: UIImage
    var onComplete: ((String) -> Void)? = nil // locationName
    
    @State private var locationName = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("LOCATION INFO")
                            .font(.poppins(32))
                            .foregroundStyle(.primary)
                        
                        Text("Name this location")
                            .font(.poppins(16))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                    
                    // Preview image
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    // Form field
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location Name")
                                .font(.poppins(14))
                                .foregroundStyle(.secondary)
                            
                            TextField("Enter location name", text: $locationName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
                        guard !locationName.isEmpty else { return }
                        onComplete?(locationName)
                        dismiss()
                    }) {
                        Text("Save Location")
                            .font(.poppins(18))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(locationName.isEmpty ? Color.gray : Color.green)
                            )
                    }
                    .disabled(locationName.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

#Preview {
    LocationInfoView(capturedImage: UIImage(systemName: "mappin.circle.fill")!)
}

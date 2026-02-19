//
//  LocationInfoFormSheet.swift
//  CarCardCollector
//
//  Form for location name (shown after composer)
//

import SwiftUI

struct LocationInfoFormSheet: View {
    let capturedImage: UIImage
    var onComplete: ((UIImage, String) -> Void)? // cardImage, locationName
    
    @State private var locationName = ""
    @Environment(\.dismiss) private var dismiss
    
    var isFormValid: Bool {
        !locationName.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
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
                            .padding(.top, 20)
                        
                        // Form field
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location Name *")
                                    .font(.poppins(14))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Enter location name", text: $locationName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Button(action: {
                            onComplete?(capturedImage, locationName)
                        }) {
                            Text("SAVE LOCATION")
                                .font(.poppins(18))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isFormValid ? Color.green : Color.gray)
                                )
                        }
                        .disabled(!isFormValid)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("LOCATION INFO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LocationInfoFormSheet(
        capturedImage: UIImage(systemName: "mappin.circle.fill")!
    )
}

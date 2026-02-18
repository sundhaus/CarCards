//
//  DriverInfoFormSheet.swift
//  CarCardCollector
//
//  Form for driver name and vehicle name (shown after composer)
//

import SwiftUI

struct DriverInfoFormSheet: View {
    let capturedImage: UIImage
    let isDriverPlusVehicle: Bool
    var onComplete: ((UIImage, String, String, String, String) -> Void)? // cardImage, firstName, lastName, nickname, vehicleName
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var vehicleName = ""
    @State private var showSignature = false
    @State private var signatureImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty
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
                            .frame(width: 200, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .padding(.top, 20)
                        
                        // Form fields
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name *")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Required", text: $firstName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name *")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Required", text: $lastName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nickname")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Optional", text: $nickname)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // Only show Vehicle Name for Driver + Vehicle captures
                            if isDriverPlusVehicle {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Vehicle Name")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("Optional", text: $vehicleName)
                                        .textFieldStyle(CustomTextFieldStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Signature button
                        Button(action: {
                            showSignature = true
                        }) {
                            HStack {
                                Image(systemName: signatureImage != nil ? "checkmark.circle.fill" : "signature")
                                    .font(.system(size: 20))
                                
                                Text(signatureImage != nil ? "Signature Added" : "Add Signature")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(signatureImage != nil ? Color.green.opacity(0.3) : Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(signatureImage != nil ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        Button(action: {
                            // Use signature image if available, otherwise use original
                            let finalCardImage = signatureImage ?? capturedImage
                            onComplete?(finalCardImage, firstName, lastName, nickname, vehicleName)
                        }) {
                            Text("Save Driver")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isFormValid ? Color.blue : Color.gray)
                                )
                        }
                        .disabled(!isFormValid)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Driver Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showSignature) {
                SignatureView(
                    cardImage: capturedImage,
                    onSignatureComplete: { signature in
                        signatureImage = signature
                        showSignature = false
                    }
                )
            }
        }
    }
}

#Preview {
    DriverInfoFormSheet(
        capturedImage: UIImage(systemName: "person.fill")!,
        isDriverPlusVehicle: false
    )
}

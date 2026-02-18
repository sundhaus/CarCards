//
//  DriverInfoView.swift
//  CarCardCollector
//
//  Driver information form with name fields and signature
//

import SwiftUI

struct DriverInfoView: View {
    let capturedImage: UIImage
    let isDriverPlusVehicle: Bool
    var onComplete: ((String, String, String) -> Void)? = nil // firstName, lastName, nickname
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var showSignature = false
    @State private var signatureImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Driver Info")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text("Add driver details")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                    
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
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // First Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("First Name")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            TextField("Required", text: $firstName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Last Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Name")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            TextField("Required", text: $lastName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Nickname (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nickname (Optional)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            TextField("Optional", text: $nickname)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Add Signature Button
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
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
                        guard !firstName.isEmpty && !lastName.isEmpty else { return }
                        onComplete?(firstName, lastName, nickname)
                        dismiss()
                    }) {
                        Text("Save Driver")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(firstName.isEmpty || lastName.isEmpty ? Color.gray : Color.blue)
                            )
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
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

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundStyle(.primary)
            .font(.system(size: 16))
    }
}

#Preview {
    DriverInfoView(capturedImage: UIImage(systemName: "person.fill")!, isDriverPlusVehicle: false)
}

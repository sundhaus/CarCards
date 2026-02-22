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
    @State private var isSaving = false
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
                        // Portrait card preview — rotated 90° like garage fullscreen
                        ZStack {
                            Image(uiImage: signatureImage ?? capturedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 158)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .rotationEffect(.degrees(90))
                            
                            // Name overlay (un-rotated, on top)
                            if !firstName.isEmpty || !lastName.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(firstName.uppercased())
                                        .font(.custom("Futura-Light", size: 16))
                                    
                                    if !nickname.isEmpty {
                                        Text("\"\(nickname.uppercased())\"")
                                            .font(.custom("Futura-Bold", size: 11))
                                            .opacity(0.8)
                                    }
                                    
                                    Text(lastName.uppercased())
                                        .font(.custom("Futura-Bold", size: 16))
                                }
                                .foregroundStyle(.white)
                                .shadow(color: .black, radius: 4, x: 0, y: 2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.top, 12)
                                .padding(.leading, 56)
                            }
                        }
                        .frame(width: 158, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                        .padding(.top, 20)
                        
                        // Form fields
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name *")
                                    .font(.poppins(14))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Required", text: $firstName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name *")
                                    .font(.poppins(14))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Required", text: $lastName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nickname")
                                    .font(.poppins(14))
                                    .foregroundStyle(.secondary)
                                
                                TextField("Optional", text: $nickname)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // Only show Vehicle Name for Driver + Vehicle captures
                            if isDriverPlusVehicle {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Vehicle Name")
                                        .font(.poppins(14))
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
                                    .font(.poppins(20))
                                
                                Text(signatureImage != nil ? "Signature Added" : "Add Signature")
                                    .font(.poppins(16))
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(signatureImage != nil ? Color.green.opacity(0.15) : Color(.systemGray5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(signatureImage != nil ? Color.green : Color(.systemGray3), lineWidth: 2)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        Button(action: {
                            guard !isSaving else { return }
                            isSaving = true
                            let finalCardImage = signatureImage ?? capturedImage
                            onComplete?(finalCardImage, firstName, lastName, nickname, vehicleName)
                        }) {
                            HStack(spacing: 10) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isSaving ? "SAVING..." : "SAVE DRIVER")
                                    .font(.poppins(18))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isFormValid && !isSaving ? Color.blue : Color.gray)
                            )
                        }
                        .disabled(!isFormValid || isSaving)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("DRIVER INFO")
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

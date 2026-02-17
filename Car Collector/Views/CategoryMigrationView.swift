//
//  CategoryMigrationView.swift
//  CarCardCollector
//
//  Admin view to backfill categories for existing cards
//  Add this to Settings or as a hidden admin option
//

import SwiftUI

struct CategoryMigrationView: View {
    @StateObject private var migrationService = CategoryMigrationService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Category Migration")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Add categories to existing cards so they appear in Explore")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // Progress info
                    if migrationService.isRunning || migrationService.processedCards > 0 {
                        VStack(spacing: 16) {
                            // Progress bar
                            if migrationService.totalCards > 0 {
                                VStack(spacing: 8) {
                                    ProgressView(value: Double(migrationService.processedCards), 
                                               total: Double(migrationService.totalCards))
                                        .tint(.blue)
                                    
                                    Text("\(migrationService.processedCards) / \(migrationService.totalCards) cards processed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Stats
                            HStack(spacing: 20) {
                                StatBox(
                                    label: "Categorized",
                                    value: "\(migrationService.categorizedCards)",
                                    color: .green
                                )
                                
                                StatBox(
                                    label: "Skipped",
                                    value: "\(migrationService.skippedCards)",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal)
                            
                            // Status message
                            Text(migrationService.migrationProgress)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            // Time estimate
                            if migrationService.isRunning {
                                Text(migrationService.estimatedTimeRemaining)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Run button
                    Button(action: {
                        Task {
                            await migrationService.migrateMissingCategories()
                        }
                    }) {
                        HStack {
                            if migrationService.isRunning {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            
                            Text(migrationService.isRunning ? "Running..." : "Start Migration")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(migrationService.isRunning ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(migrationService.isRunning)
                    .padding(.horizontal)
                    
                    // Info text
                    VStack(spacing: 8) {
                        Text("This will:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow(text: "Scan all existing cards")
                            InfoRow(text: "Use AI to determine category")
                            InfoRow(text: "Update cards in Firestore")
                            InfoRow(text: "Skip cards that already have categories")
                        }
                        .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InfoRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            
            Text(text)
        }
    }
}

#Preview {
    CategoryMigrationView()
}

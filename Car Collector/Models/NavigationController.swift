//
//  NavigationController.swift
//  CarCardCollector
//
//  Manages navigation state across tabs - allows hub buttons to reset to front page
//

import SwiftUI

@MainActor
class NavigationController: ObservableObject {
    static let shared = NavigationController()
    
    @Published var homeNavigationPath = NavigationPath()
    @Published var garageNavigationPath = NavigationPath()
    @Published var marketplaceNavigationPath = NavigationPath()
    @Published var shopNavigationPath = NavigationPath()
    
    // Triggers to signal pop to root
    @Published var popToRootTrigger: Int = 0
    
    private init() {}
    
    // Call this when a hub button is tapped - ALWAYS resets to root
    func resetToRoot(tab: Int) {
        // Always clear the navigation path for the tapped tab
        switch tab {
        case 0:
            homeNavigationPath = NavigationPath()
        case 1:
            garageNavigationPath = NavigationPath()
        case 2:
            marketplaceNavigationPath = NavigationPath()
        case 3:
            shopNavigationPath = NavigationPath()
        default:
            break
        }
        
        popToRootTrigger += 1
        print("🔄 Reset navigation for tab \(tab)")
    }
    
    // Reset all navigation paths (useful for logout/reset)
    func resetAll() {
        homeNavigationPath = NavigationPath()
        garageNavigationPath = NavigationPath()
        marketplaceNavigationPath = NavigationPath()
        shopNavigationPath = NavigationPath()
        popToRootTrigger += 1
    }
}

//
//  NavigationController.swift
//  CarCardCollector
//
//  Manages navigation state across tabs - resets to root on tab switch
//

import SwiftUI

@MainActor
class NavigationController: ObservableObject {
    static let shared = NavigationController()
    
    @Published var homeNavigationPath = NavigationPath()
    @Published var garageNavigationPath = NavigationPath()
    @Published var marketplaceNavigationPath = NavigationPath()
    @Published var shopNavigationPath = NavigationPath()
    
    private init() {}
    
    /// Reset navigation for a specific tab (matches ContentView tab values)
    /// 0=Shop, 1=Home, 2=Capture, 3=Market, 4=Garage
    func resetToRoot(tab: Int) {
        switch tab {
        case 0: shopNavigationPath = NavigationPath()
        case 1: homeNavigationPath = NavigationPath()
        case 3: marketplaceNavigationPath = NavigationPath()
        case 4: garageNavigationPath = NavigationPath()
        default: break  // Capture (2) has no persistent nav stack
        }
        // Also triggers boolean-based navigation resets in views
        popToRootTrigger += 1
    }
    
    // Incremented to signal views to dismiss boolean-based navigation
    @Published var popToRootTrigger: Int = 0
    
    /// Reset all navigation paths
    func resetAll() {
        homeNavigationPath = NavigationPath()
        garageNavigationPath = NavigationPath()
        marketplaceNavigationPath = NavigationPath()
        shopNavigationPath = NavigationPath()
        popToRootTrigger += 1
    }
}

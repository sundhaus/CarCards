//
//  NavigationController.swift
//  CarCardCollector
//
//  Manages navigation state across tabs - resets to root on tab switch
//  with selective preservation for deep pages (profiles, buy/sell)
//

import SwiftUI
import Combine

@MainActor
class NavigationController: ObservableObject {
    static let shared = NavigationController()
    
    @Published var homeNavigationPath = NavigationPath()
    @Published var garageNavigationPath = NavigationPath()
    @Published var marketplaceNavigationPath = NavigationPath()
    @Published var shopNavigationPath = NavigationPath()
    
    // Tabs that should NOT be reset on next tab switch
    // Views add their tab here when on a deep page worth preserving
    @Published var preservedTabs: Set<Int> = []
    
    // Incremented to signal views to dismiss boolean-based navigation
    @Published var popToRootTrigger: Int = 0
    
    private init() {}
    
    /// Mark a tab as preserved (won't reset on next tab switch)
    func preserveTab(_ tab: Int) {
        preservedTabs.insert(tab)
    }
    
    /// Clear preservation for a tab (will reset normally)
    func unpreserveTab(_ tab: Int) {
        preservedTabs.remove(tab)
    }
    
    /// Reset navigation for a specific tab (matches ContentView tab values)
    /// 0=Shop, 1=Home, 2=Capture, 3=Market, 4=Garage
    /// Skips tabs in preservedTabs set
    func resetToRoot(tab: Int) {
        // Skip if this tab is preserved
        if preservedTabs.contains(tab) { return }
        
        switch tab {
        case 0: shopNavigationPath = NavigationPath()
        case 1: homeNavigationPath = NavigationPath()
        case 3: marketplaceNavigationPath = NavigationPath()
        case 4: garageNavigationPath = NavigationPath()
        default: break
        }
        popToRootTrigger += 1
    }
    
    /// Force reset a specific tab (ignores preservation)
    func forceResetToRoot(tab: Int) {
        preservedTabs.remove(tab)
        switch tab {
        case 0: shopNavigationPath = NavigationPath()
        case 1: homeNavigationPath = NavigationPath()
        case 3: marketplaceNavigationPath = NavigationPath()
        case 4: garageNavigationPath = NavigationPath()
        default: break
        }
        popToRootTrigger += 1
    }
    
    /// Reset all navigation paths
    func resetAll() {
        preservedTabs.removeAll()
        homeNavigationPath = NavigationPath()
        garageNavigationPath = NavigationPath()
        marketplaceNavigationPath = NavigationPath()
        shopNavigationPath = NavigationPath()
        popToRootTrigger += 1
    }
}

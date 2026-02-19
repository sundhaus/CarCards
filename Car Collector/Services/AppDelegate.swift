//
//  AppDelegate.swift
//  CarCardCollector
//
//  App delegate for orientation support
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // Portrait only - no landscape allowed
    static var orientationLock: UIInterfaceOrientationMask = .portrait
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // ✅ Configure Firebase FIRST - before any Firebase services are accessed
        FirebaseManager.configure()
        
        // Watch for any orientation changes and force back to portrait
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            OrientationManager.forcePortrait()
        }
        
        return true
    }
    
    // Additional methods for Firebase compatibility
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

// Orientation lock helper - actively forces portrait
struct OrientationManager {
    static func forcePortrait() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                // Silently handle - portrait is already enforced via AppDelegate
            }
        }
    }
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, rotate: Bool = false) {
        forcePortrait()
    }
    
    static func lockToPortrait() {
        forcePortrait()
    }
    
    static func unlockOrientation() {
        forcePortrait()
    }
}

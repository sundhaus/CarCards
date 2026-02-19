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
        
        // Limit URL cache to 20MB memory / 50MB disk (default is 4MB/20MB)
        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024,
            diskPath: "url_cache"
        )
        
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
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        CardImageStore.shared.clearCache()
        URLCache.shared.removeAllCachedResponses()
        print("⚠️ AppDelegate: memory warning - cleared caches")
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

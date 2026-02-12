//
//  AppDelegate.swift
//  CarCardCollector
//
//  App delegate for orientation support
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // Only allow portrait and landscape-right (home button on left, notch/island on right)
    // Explicitly exclude landscape-left
    static var orientationLock: UIInterfaceOrientationMask = [.portrait, .landscapeRight]
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase is configured in Car_CollectorApp.init() via FirebaseManager.configure()
        // This method just needs to exist to satisfy UIApplicationDelegate protocol
        return true
    }
    
    // Additional methods for Firebase compatibility
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Firebase needs this for push notifications (even if not used yet)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Firebase needs this for background notifications
        completionHandler(.noData)
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

// Orientation lock helper
struct OrientationManager {
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            AppDelegate.orientationLock = orientation
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    }
    
    static func unlockOrientation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            // Only unlock to portrait and landscape-right (excludes landscape-left)
            AppDelegate.orientationLock = [.portrait, .landscapeRight]
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: [.portrait, .landscapeRight]))
        }
    }
}

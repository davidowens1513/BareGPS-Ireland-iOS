//
//  AppDelegate.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        OfflineMapDownloadManager.shared?.reconnectToBackgroundTasks()
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == OfflineMapConfiguration.backgroundSessionIdentifier,
              let manager = OfflineMapDownloadManager.shared else {
            completionHandler()
            return
        }
        manager.handleBackgroundEvents(completionHandler: completionHandler)
    }
}

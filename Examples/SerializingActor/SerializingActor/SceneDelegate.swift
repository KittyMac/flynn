//
//  SceneDelegate.swift
//  SerializingActor
//
//  Created by Rocco Bowling on 8/9/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var model = ConcurrentData()

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(model)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {

    }

    func sceneDidBecomeActive(_ scene: UIScene) {

    }

    func sceneWillResignActive(_ scene: UIScene) {

    }

    // We want to save and load our model's state when the app is foregrounded
    // and backgrounded. We simply call our beLoadState() and beSaveState()
    // behaviors on our models.

    func sceneWillEnterForeground(_ scene: UIScene) {
        model.beLoadState()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        model.beSaveState()
    }

}

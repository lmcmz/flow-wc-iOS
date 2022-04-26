//
//  WCWalletApp.swift
//  WCWallet
//
//  Created by Hao Fu on 27/2/2022.
//

import SwiftUI

@main
struct WCWalletApp: App {
    
    @ObservedObject
    var viewModel = ViewModel()
    
    init() {
        viewModel.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
            .onOpenURL { url in
                print(url)
                self.viewModel.updateDeepLink(deepLink: url)
            }
        }
    }
}

//
//  WCWalletApp.swift
//  WCWallet
//
//  Created by Hao Fu on 27/2/2022.
//

import SwiftUI
import WalletConnectSign
import WalletConnectRelay
import Starscream

extension WebSocket: WebSocketConnecting { }

struct SocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
}


@main
struct WCWalletApp: App {
    
    @ObservedObject
    var viewModel = ViewModel()
    
    init() {
        let metadata = AppMetadata(
            name: "Flow Wallet",
            description: "wallet description",
            url: "https://lilico.app",
            icons: ["https://github.com/Outblock/Assets/blob/main/blockchain/flow/info/logo.png?raw=true"])
        Sign.configure(metadata: metadata, projectId: "b00f6d1baf6e7a6ea324c394932bace2", socketFactory: SocketFactory())
        viewModel.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
            .onOpenURL { url in
                print(url)
                self.viewModel.updateDeepLink(deepLink: url)
            }
            .onAppear {
                viewModel.setup()
            }
        }
    }
}

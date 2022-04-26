//
//  ViewModel.swift
//  WCWallet
//
//  Created by Hao Fu on 27/2/2022.
//

import Foundation
import WalletConnect
import SwiftUI

struct ActiveSessionItem: Identifiable, Equatable {
    let id = UUID()
    let dappName: String
    let dappURL: String
    let iconURL: String
    let topic: String
}


class ViewModel: ObservableObject {
    
    @Published
    var link: String = ""
    
    @Published
    var showPopUp: Bool = false
    
    var currentProposal: Session.Proposal?
    
    var currentSessionInfo: SessionInfo?
    
    @Published
    var sessionItems: [ActiveSessionItem] = []
    
    let client: WalletConnectClient = {
        let metadata = AppMetadata(
            name: "Flow Wallet",
            description: "wallet description",
            url: "https://lilico.app",
            icons: ["https://github.com/Outblock/Assets/blob/main/blockchain/flow/info/logo.png?raw=true"])
        return WalletConnectClient(
            metadata: metadata,
            projectId: "b00f6d1baf6e7a6ea324c394932bace2",
            relayHost: "relay.walletconnect.com"
        )
    }()
    
//    init(deepLink: URL?) {
////        super.init()
//    }
    
    func updateDeepLink(deepLink: URL?) {
        setup()
        link = (deepLink?.absoluteString.replacingOccurrences(of: "fwc://", with: ""))!
        connect()
    }
    
    func setup() {
        client.delegate = self
        let settledSessions = client.getSettledSessions()
        sessionItems = getActiveSessionItem(for: settledSessions)
    }
    
    func connect() {
        do {
            try client.pair(uri: link)
        } catch let e {
            print(e)
        }
    }
    
    func getActiveSessionItem(for settledSessions: [Session]) -> [ActiveSessionItem] {
        return settledSessions.map { session -> ActiveSessionItem in
            let app = session.peer
            return ActiveSessionItem(
                dappName: app.name ?? "",
                dappURL: app.url ?? "",
                iconURL: app.icons?.first ?? "",
                topic: session.topic)
        }
    }
    
    func reloadActiveSessions() {
        let settledSessions = client.getSettledSessions()
        let activeSessions = getActiveSessionItem(for: settledSessions)
        DispatchQueue.main.async { // FIXME: Delegate being called from background thread
            self.sessionItems = activeSessions
//            self.responderView.tableView.reloadData()
        }
    }
    
    func disconnect(_ sessionItem: ActiveSessionItem) {
        client.disconnect(topic: sessionItem.topic, reason: .init(code: 0, message: "disconnect"))
        guard let index = sessionItems.firstIndex(where: { item in
            item == sessionItem
        }) else {
            return
        }
        sessionItems.remove(at: index)
    }
    
    func didApproveSession() {
        print("[RESPONDER] Approving session...")
        showPopUp = false
        guard let proposal = currentProposal else {
            return
        }
        currentProposal = nil
        let accounts = Set(proposal.permissions.blockchains.compactMap { Account($0+":0x123") })
        client.approve(proposal: proposal, accounts: accounts)
    }
    
    func didRejectSession() {
        print("did reject session")
        showPopUp = false
        guard let proposal = currentProposal else {
            return
        }
        currentProposal = nil
        client.reject(proposal: proposal, reason: .disapprovedChains)
    }

}

extension ViewModel: WalletConnectClientDelegate {
    
    func didSettle(session: Session) {
        print("<-- didSettle -->")
        reloadActiveSessions()
    }
    
    func didUpdate(sessionTopic: String, accounts: Set<Account>) {
        print("<-- didUpdate -->")
//        client.notify(topic: "authn", params: Session.Notification.self, completion: nil)
        client.notify(topic: <#T##String#>, params: <#T##Session.Notification#>, completion: <#T##((Error?) -> ())?##((Error?) -> ())?##(Error?) -> ()#>)
    }
    
    func didDelete(sessionTopic: String, reason: Reason) {
        print("<-- didDelete -->")
        reloadActiveSessions()
    }
    
    func didUpgrade(sessionTopic: String, permissions: Session.Permissions) {
        print("<-- didUpgrade -->")
    }
    
    func didReceive(sessionRequest: Request) {
        print("<-- didReceive -->")
        
//        currentProposal = sessionProposal
//        let appMetadata = sessionProposal.proposer
        let info = SessionInfo(
            name: sessionRequest.method ?? "",
            descriptionText: sessionRequest.chainId ?? "",
            dappURL: "",
            iconURL: "",
            chains: [],
            methods: [],
            pendingRequests: []
        )
        currentSessionInfo = info
        
        DispatchQueue.main.async {
            self.showPopUp = true
        }
    }
    
    func didReceive(sessionProposal: Session.Proposal) {
        print("<-- didReceive sessionProposal -->")
        currentProposal = sessionProposal
        let appMetadata = sessionProposal.proposer
        let info = SessionInfo(
            name: appMetadata.name ?? "",
            descriptionText: appMetadata.description ?? "",
            dappURL: appMetadata.url ?? "",
            iconURL: appMetadata.icons?.first ?? "",
            chains: Array(sessionProposal.permissions.blockchains),
            methods: Array(sessionProposal.permissions.methods), pendingRequests: [])
        currentSessionInfo = info
        
        DispatchQueue.main.async {
            self.showPopUp = true
        }
    }
    
    
}

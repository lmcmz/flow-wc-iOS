//
//  ViewModel.swift
//  WCWallet
//
//  Created by Hao Fu on 27/2/2022.
//

import Foundation
import SwiftUI
import WalletConnectUtils
import WalletConnectSign
import Combine

struct AuthzRequestModel: Codable {
    let referenceId: String
    let cadence: String
    let args: [CadenceArgument]
}

struct AuthzReponseModel: Codable {
//    let referenceId: String
//    let cadence: String
    let signature: String
    
    init(signature: String) {
//        self.referenceId = referenceId
//        self.cadence = cadence
        self.signature = signature
    }
}

struct CadenceArgument: Codable {
    let type: String
    let value: String
}

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
    
    private var publishers = [AnyCancellable]()
    
    init() {
    }
    
    func updateDeepLink(deepLink: URL?) {
        setup()
        link = (deepLink?.absoluteString.replacingOccurrences(of: "fwc://", with: ""))!
        connect()
    }
    
    func setup() {
        let settledSessions = Sign.instance.getSessions()
        sessionItems = getActiveSessionItem(for: settledSessions)
        setUpAuthSubscribing()
    }
    
    func connect() {
        print("[RESPONDER] Pairing to: \(link)")
        Task {
            do {
                try await Sign.instance.pair(uri: link)
            } catch {
                print("[PROPOSER] Pairing connect error: \(error)")
            }
        }
    }
    
    func getActiveSessionItem(for settledSessions: [Session]) -> [ActiveSessionItem] {
        return settledSessions.map { session -> ActiveSessionItem in
            let app = session.peer
            return ActiveSessionItem(
                dappName: app.name ?? "",
                dappURL: app.url ?? "",
                iconURL: app.icons.first ?? "",
                topic: session.topic)
        }
    }
    
    func reloadActiveSessions() {
        let settledSessions = Sign.instance.getSessions()
        let activeSessions = getActiveSessionItem(for: settledSessions)
        DispatchQueue.main.async { // FIXME: Delegate being called from background thread
            self.sessionItems = activeSessions
//            self.walletView.tableView.reloadData()
        }
    }
    
    func disconnect(_ sessionItem: ActiveSessionItem) {
        Task {
            do {
                try await Sign.instance.disconnect(topic: sessionItem.topic, reason: Reason(code: 0, message: "disconnect"))
                guard let index = sessionItems.firstIndex(where: { item in
                    item == sessionItem
                }) else {
                    return
                }
                sessionItems.remove(at: index)
            } catch {
                print(error)
            }
        }
    }
    
    func didApproveSession() {
        print("[RESPONDER] Approving session...")
        showPopUp = false
        guard let proposal = currentProposal else {
            return
        }
        currentProposal = nil
//        let accounts = Set(proposal.permissions.blockchains.compactMap { Account($0+":0x123") })
//        client.approve(proposal: proposal, accounts: accounts)
        
        let account = "0x123"
        var sessionNamespaces = [String: SessionNamespace]()
        proposal.requiredNamespaces.forEach {
            let caip2Namespace = $0.key
            let proposalNamespace = $0.value
            let accounts = Set(proposalNamespace.chains.compactMap { Account($0.absoluteString + ":\(account)") } )
            
            let extensions: [SessionNamespace.Extension]? = proposalNamespace.extensions?.map { element in
                let accounts = Set(element.chains.compactMap { Account($0.absoluteString + ":\(account)") } )
                return SessionNamespace.Extension(accounts: accounts, methods: element.methods, events: element.events)
            }
            let sessionNamespace = SessionNamespace(accounts: accounts, methods: proposalNamespace.methods, events: proposalNamespace.events, extensions: extensions)
            sessionNamespaces[caip2Namespace] = sessionNamespace
        }
        try! Sign.instance.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
    }
    
    func didRejectSession() {
        print("did reject session")
        showPopUp = false
        guard let proposal = currentProposal else {
            return
        }
        currentProposal = nil
//        client.reject(proposal: proposal, reason: .disapprovedChains)
    }
}

extension ViewModel {
    func setUpAuthSubscribing() {
        Sign.instance.socketConnectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .connected {
//                    self?.onClientConnected?()
                    print("Client connected")
                }
            }.store(in: &publishers)

        // TODO: Adapt proposal data to be used on the view
        Sign.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionProposal in
                print("[RESPONDER] WC: Did receive session proposal")
                self?.currentProposal = sessionProposal
                
                let appMetadata = sessionProposal.proposer
                let info = SessionInfo(
                    name: appMetadata.name ?? "",
                    descriptionText: appMetadata.description ?? "",
                    dappURL: appMetadata.url ?? "",
                    iconURL: appMetadata.icons.first ?? "",
                    chains: [],
                    methods: [],
                    pendingRequests: [],
                    data: "")
                self?.currentSessionInfo = info
                DispatchQueue.main.async {
                    self?.showPopUp = true
                }
                
//                    self?.showSessionProposal(Proposal(proposal: sessionProposal)) // FIXME: Remove mock
            }.store(in: &publishers)

        Sign.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadActiveSessions()
            }.store(in: &publishers)

        Sign.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRequest in
                print("[RESPONDER] WC: Did receive session request")
//                self?.showSessionRequest(sessionRequest)
            }.store(in: &publishers)

        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRequest in
                self?.reloadActiveSessions()
//                self?.navigationController?.popToRootViewController(animated: true)
            }.store(in: &publishers)
    }
}

//extension ViewModel: WalletConnectClientDelegate {
//
//    func didSettle(session: Session) {
//        print("<-- didSettle -->")
//        reloadActiveSessions()
//    }
//
//    func didUpdate(sessionTopic: String, accounts: Set<Account>) {
//        print("<-- didUpdate -->")
////        client.notify(topic: "authn", params: Session.Notification.self, completion: nil)
//    }
//
//    func didDelete(sessionTopic: String, reason: Reason) {
//        print("<-- didDelete -->")
//        reloadActiveSessions()
//    }
//
//    func didUpgrade(sessionTopic: String, permissions: Session.Permissions) {
//        print("<-- didUpgrade -->")
//    }
//
//    func didReceive(sessionRequest: Request) {
//        print("<-- didReceive -->")
//
////        currentProposal = sessionProposal
////        let appMetadata = sessionProposal.proposer
//
//        let json = try! sessionRequest.params.json()
//
//        let info = SessionInfo(
//            name: sessionRequest.method ?? "",
//            descriptionText: sessionRequest.chainId ?? "",
//            dappURL: "",
//            iconURL: "",
//            chains: [],
//            methods: [],
//            pendingRequests: [],
//            data: json
//        )
//        currentSessionInfo = info
//
//        DispatchQueue.main.async {
//            self.showPopUp = true
//        }
//
//        let model = try! sessionRequest.params.get(AuthzRequestModel.self)
//        let result = AnyCodable(AuthzReponseModel(signature: "0xsignature"))
//        let response = JSONRPCResponse<AnyCodable>(id: sessionRequest.id, result: result)
//        client.respond(topic: sessionRequest.topic, response: .response(response))
//    }
//
//    func didReceive(sessionProposal: Session.Proposal) {
//        print("<-- didReceive sessionProposal -->")
//        currentProposal = sessionProposal
//        let appMetadata = sessionProposal.proposer
//        let info = SessionInfo(
//            name: appMetadata.name ?? "",
//            descriptionText: appMetadata.description ?? "",
//            dappURL: appMetadata.url ?? "",
//            iconURL: appMetadata.icons?.first ?? "",
//            chains: Array(sessionProposal.permissions.blockchains),
//            methods: Array(sessionProposal.permissions.methods),
//            pendingRequests: [],
//            data: "")
//        currentSessionInfo = info
//
//        DispatchQueue.main.async {
//            self.showPopUp = true
//        }
//    }
//
//
//}

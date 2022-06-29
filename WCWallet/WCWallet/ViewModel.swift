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
    
    @Published
    var showRequestPopUp: Bool = false

    
    var currentProposal: Session.Proposal?
    
    var currentRequest: WalletConnectSign.Request?
    
    var currentSessionInfo: SessionInfo?
    
    var currentRequestInfo: RequestInfo?
    
    @Published
    var sessionItems: [ActiveSessionItem] = []
    
    @Published
    var activePairings: [Pairing] = []
    
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
        reloadPairing()
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
    
    func reloadPairing() {
        let activePairings: [Pairing] = Sign.instance.getSettledPairings()
//        Sign.instance.client.pairingEngine.pairingStore
        self.activePairings = activePairings
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
        let account = "0x" + FlowWallet.instance.address.hex
        var sessionNamespaces = [String: SessionNamespace]()
        proposal.requiredNamespaces.forEach {
            let caip2Namespace = $0.key
            let proposalNamespace = $0.value
            let accounts = Set(proposalNamespace.chains.compactMap { WalletConnectSign.Account($0.absoluteString + ":\(account)") } )
            
            let extensions: [SessionNamespace.Extension]? = proposalNamespace.extensions?.map { element in
                let accounts = Set(element.chains.compactMap { WalletConnectSign.Account($0.absoluteString + ":\(account)") } )
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
        Sign.instance.reject(proposal: proposal, reason: .disapprovedChains)
    }
    
    func didApproveRequest() {
        
        showRequestPopUp = false
        guard let request = currentRequest, let requestInfo = currentRequestInfo else {
            return
        }
        currentRequest = nil

        do {
            let address = "0x" + FlowWallet.instance.address.hex
            let signature = try FlowWallet.instance.sign(message: requestInfo.message)
            let result = AuthnResponse(fType: "PollingResponse", fVsn: "1.0.0", status: .approved,
                                       data: AuthnData(addr: address, fType: "CompositeSignature", fVsn: "1.0.0", services: nil, signature: signature),
                                       reason: nil,
                                       compositeSignature: nil)
            let response = JSONRPCResponse<AnyCodable>(id: request.id, result: AnyCodable(result))
            Sign.instance.respond(topic: request.topic, response: .response(response))
        } catch {
            print(error)
            Sign.instance.respond(topic: request.topic, response: .error(.init(id: 0, error: .init(code: 0, message: "NOT Handle"))))
        }
    }
    
    
    func didRejectRequest() {
        showRequestPopUp = false
        
        guard let request = currentRequest else {
            return
        }
        let reason = "User reject request"
        let response = JSONRPCResponse<AnyCodable>(id: 0, result: AnyCodable(reason))
        Sign.instance.respond(topic: request.topic, response: .response(response))
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
                let requiredNamespaces = sessionProposal.requiredNamespaces
                let info = SessionInfo(
                    name: appMetadata.name ?? "",
                    descriptionText: appMetadata.description ?? "",
                    dappURL: appMetadata.url ?? "",
                    iconURL: appMetadata.icons.first ?? "",
                    chains: requiredNamespaces["flow"]?.chains ?? [],
                    methods: requiredNamespaces["flow"]?.methods ?? [],
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
                
                
                switch sessionRequest.method {
                case "flow_authn":
                    let address = "0x" + FlowWallet.instance.address.hex
                    let keyId = FlowWallet.instance.keyId
                    let result = AuthnResponse(fType: "PollingResponse", fVsn: "1.0.0", status: .approved,
                                               data: AuthnData(addr: address, fType: "AuthnResponse", fVsn: "1.0.0",
                                                               services: [
                                                                serviceDefinition(address: address, keyId: keyId, type: .authn),
                                                                serviceDefinition(address: address, keyId: keyId, type: .authz)
                                                               ]),
                                               reason: nil,
                                               compositeSignature: nil)
                    let response = JSONRPCResponse<AnyCodable>(id: sessionRequest.id, result: AnyCodable(result))
                    Sign.instance.respond(topic: sessionRequest.topic, response: .response(response))
                case "flow_authz":
                    
                    do {
                        self?.currentRequest = sessionRequest
                        let jsonString = try sessionRequest.params.get(String.self)
                        let data = jsonString.data(using: .utf8)!
                        let model = try JSONDecoder().decode(Signable.self, from: data)

                        if let session = self?.sessionItems.first{ $0.topic == sessionRequest.topic } {
                            let request = RequestInfo(cadence: model.cadence ?? "", agrument: model.args, name: session.dappName, descriptionText: session.dappURL, dappURL: session.dappURL, iconURL: session.iconURL, chains: Set(arrayLiteral: sessionRequest.chainId), methods: nil, pendingRequests: [], message: model.message)
                            self?.currentRequestInfo = request
                            DispatchQueue.main.async {
                                self?.showRequestPopUp = true
                            }
                        }
                        
                    } catch {
                        print(error)
                        Sign.instance.respond(topic: sessionRequest.topic, response: .error(.init(id: 0, error: .init(code: 0, message: "NOT Handle"))))
                    }
                    
                default:
                    Sign.instance.respond(topic: sessionRequest.topic, response: .error(.init(id: 0, error: .init(code: 0, message: "NOT Handle"))))
                }

            }.store(in: &publishers)

        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRequest in
                self?.reloadActiveSessions()
//                self?.navigationController?.popToRootViewController(animated: true)
            }.store(in: &publishers)
        
        Sign.instance.sessionEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRequest in
                print("[RESPONDER] WC: sessionEventPublisher")
//                self?.showSessionRequest(sessionRequest)
            }.store(in: &publishers)
        
        Sign.instance.sessionUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionRequest in
                print("[RESPONDER] WC: sessionUpdatePublisher")
//                self?.showSessionRequest(sessionRequest)
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

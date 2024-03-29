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
import Flow

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
    
    @Published
    var showRequestMessagePopUp: Bool = false

    
    var currentProposal: Session.Proposal?
    
    var currentRequest: WalletConnectSign.Request?
    
    var currentSessionInfo: SessionInfo?
    
    var currentRequestInfo: RequestInfo?
    
    var currentMessageInfo: RequestMessageInfo?
    
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
                try await Sign.instance.disconnect(topic: sessionItem.topic)
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
    
    func didApproveSession() async {
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
        do {
            try await Sign.instance.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
        } catch {
            print("[WALLET] Respond Error: \(error.localizedDescription)")
        }
    }
    
    func didRejectSession() async {
        print("did reject session")
        showPopUp = false
        guard let proposal = currentProposal else {
            return
        }
        currentProposal = nil
        do {
            try await Sign.instance.reject(proposalId: proposal.id, reason: .disapprovedChains)
        } catch {
            print("[WALLET] Respond Error: \(error.localizedDescription)")
        }
    }
    
    func didApproveRequest() async {
        
        showRequestPopUp = false
        guard let request = currentRequest, let requestInfo = currentRequestInfo else {
            return
        }
        currentRequest = nil

        do {
            let address = "0x" + FlowWallet.instance.address.hex
            let signature = try FlowWallet.instance.sign(message: requestInfo.message)
            let result = AuthnResponse(fType: "PollingResponse", fVsn: "1.0.0", status: .approved,
                                       data: AuthnData(addr: address, fType: "CompositeSignature", fVsn: "1.0.0", services: nil, keyId: 0, signature: signature),
                                       reason: nil,
                                       compositeSignature: nil)
            let response = JSONRPCResponse<AnyCodable>(id: request.id, result: AnyCodable(result))
            try await Sign.instance.respond(topic: request.topic, response: .response(response))
        } catch {
            print(error)
            
            do {
                try await Sign.instance.respond(topic: request.topic, response: .error(.init(id: 0, error: .init(code: 0, message: error.localizedDescription))))
            } catch {
                print(error)
            }
            
        }
    }
    
    func didMessageApproveRequest() async {
        
        showRequestMessagePopUp = false
        guard let request = currentRequest, let requestInfo = currentMessageInfo else {
            return
        }
        currentMessageInfo = nil

        do {
            let address = "0x" + FlowWallet.instance.address.hex
            let signature = try FlowWallet.instance.signUserMessage(message: requestInfo.message)
            let result = AuthnResponse(fType: "PollingResponse", fVsn: "1.0.0", status: .approved,
                                       data: AuthnData(addr: address, fType: "CompositeSignature", fVsn: "1.0.0", services: nil, keyId: 0, signature: signature),
                                       reason: nil,
                                       compositeSignature: nil)
            let response = JSONRPCResponse<AnyCodable>(id: request.id, result: AnyCodable(result))
            try await Sign.instance.respond(topic: request.topic, response: .response(response))
        } catch {
            print(error)
            
            do {
                try await Sign.instance.respond(topic: request.topic, response: .error(.init(id: 0, error: .init(code: 0, message: error.localizedDescription))))
            } catch {
                print(error)
            }
            
        }
    }
    
    
    func didRejectRequest() async {
        showRequestPopUp = false
        
        guard let request = currentRequest else {
            return
        }
        let reason = "User reject request"
        let response = JSONRPCResponse<AnyCodable>(id: 0, result: AnyCodable(reason))
        
        do {
            try await Sign.instance.respond(topic: request.topic, response: .response(response))
        } catch {
            print("[WALLET] Respond Error: \(error.localizedDescription)")
        }
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
                case FCLWalletConnectMethod.authn.rawValue:
                    let address = "0x" + FlowWallet.instance.address.hex
                    let keyId = FlowWallet.instance.keyId
                    let result = AuthnResponse(fType: "PollingResponse", fVsn: "1.0.0", status: .approved,
                                               data: AuthnData(addr: address, fType: "AuthnResponse", fVsn: "1.0.0",
                                                               services: [
                                                                serviceDefinition(address: address, keyId: keyId, type: .authn),
                                                                serviceDefinition(address: address, keyId: keyId, type: .authz),
                                                                serviceDefinition(address: address, keyId: keyId, type: .userSignature)
                                                               ]),
                                               reason: nil,
                                               compositeSignature: nil)
                    let response = JSONRPCResponse<AnyCodable>(id: sessionRequest.id, result: AnyCodable(result))
                    
                    Task {
                        do {
                            try await Sign.instance.respond(topic: sessionRequest.topic, response: .response(response))
                        } catch {
                            print("[WALLET] Respond Error: \(error.localizedDescription)")
                        }
                    }
                    
                case FCLWalletConnectMethod.authz.rawValue:
                    
                    do {
                        self?.currentRequest = sessionRequest
                        let jsonString = try sessionRequest.params.get([String].self)
                        let data = jsonString[0].data(using: .utf8)!
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
                        
                        Task {
                            do {
                                try await Sign.instance.respond(topic: sessionRequest.topic, response: .error(.init(id: 0, error: .init(code: 0, message: "NOT Handle"))))
                            } catch {
                                print("[WALLET] Respond Error: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                case FCLWalletConnectMethod.userSignature.rawValue:
                    
                    do {
                        self?.currentRequest = sessionRequest
                        let jsonString = try sessionRequest.params.get([String].self)
                        let data = jsonString[0].data(using: .utf8)!
                        let model = try JSONDecoder().decode(SignableMessage.self, from: data)

                        if let session = self?.sessionItems.first{ $0.topic == sessionRequest.topic } {
                            let request = RequestMessageInfo(name: session.dappName, descriptionText: session.dappURL, dappURL: session.dappURL, iconURL: session.iconURL, chains: Set(arrayLiteral: sessionRequest.chainId), methods: nil, pendingRequests: [], message: model.message)
                            self?.currentMessageInfo = request
                            DispatchQueue.main.async {
                                self?.showRequestMessagePopUp = true
                            }
                        }
                        
                    } catch {
                        print(error)
                        
                        Task {
                            do {
                                try await Sign.instance.respond(topic: sessionRequest.topic, response: .error(.init(id: 0, error: .init(code: 0, message: "NOT Handle"))))
                            } catch {
                                print("[WALLET] Respond Error: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                default:
                    Task {
                        do {
                            try await Sign.instance.respond(topic: sessionRequest.topic, response: .error(.init(id: 0, error: .init(code: 0, message: "NOT Handle"))))
                        } catch {
                            print("[WALLET] Respond Error: \(error.localizedDescription)")
                        }
                    }
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

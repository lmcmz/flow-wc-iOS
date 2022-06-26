//
//  FlowWalletCore.swift
//  WCWallet
//
//  Created by Hao Fu on 7/6/2022.
//

import Foundation
import Flow
import CryptoKit

struct ECDSA_P256_Signer: FlowSigner {
    var address: Flow.Address
    var keyIndex: Int
    var hashAlgo: Flow.HashAlgorithm = .SHA2_256
    var signatureAlgo: Flow.SignatureAlgorithm = .ECDSA_P256

    var privateKey: P256.Signing.PrivateKey

    init(address: Flow.Address, keyIndex: Int, privateKey: P256.Signing.PrivateKey) {
        self.address = address
        self.keyIndex = keyIndex
        self.privateKey = privateKey
    }

    func sign(signableData: Data) throws -> Data {
        do {
            return try privateKey.signature(for: signableData).rawRepresentation
        } catch {
            throw error
        }
    }
}

class FlowWallet {
    static let instance = FlowWallet()
    let address = Flow.Address(hex: "0xc6de0d94160377cd")
    let keyId = 0
    let publicKey = try! P256.KeyAgreement.PublicKey(rawRepresentation: "d487802b66e5c0498ead1c3f576b718949a3500218e97a6a4a62bf69a8b0019789639bc7acaca63f5889c1e7251c19066abb09fcd6b273e394a8ac4ee1a3372f".hexValue)
    let privateKey = try! P256.Signing.PrivateKey(rawRepresentation: "c9c0f04adddf7674d265c395de300a65a777d3ec412bba5bfdfd12cffbbb78d9".hexValue)
    
    func sign(message: String) throws -> String {
        let signer = ECDSA_P256_Signer(address: address, keyIndex: 0, privateKey: privateKey)
        let data = try signer.sign(signableData: Data(message.hexValue))
        return data.hexValue
    }
    
}


func serviceDefinition(address: String, keyId: Int, type: FCLServiceType) -> Service {
    
    var service = Service(fType: "Service",
                          fVsn: "1.0.0",
                          type: type,
                          method: .none,
                          endpoint: nil,
                          uid: "flow-wallet#" + type.rawValue,
                          id: nil,
                          identity: nil,
                          provider: nil, params: nil)
    
    if type == .authn {
        service.id = address
        service.identity = Identity(address: address, keyId: keyId)
        service.provider = Provider(fType: "ServiceProvider", fVsn: "1.0.0", address: address, name: "Flow Wallet")
        service.endpoint = "flow_authn"
    }
    
    if type == .authz {
        service.method = .walletConnect
        service.identity = Identity(address: address, keyId: keyId)
        service.endpoint = "flow_authz"
    }
    
    
    return service
}

//
//  RequestMessageView.swift
//  WCWallet
//
//  Created by Hao Fu on 26/7/2022.
//

import SwiftUI
import Flow
import WalletConnectSign

struct RequestMessageInfo {
    let name: String
    let descriptionText: String
    let dappURL: String
    let iconURL: String
    let chains: Set<Blockchain>?
    let methods: Set<String>?
    let pendingRequests: [String]
    let message: String
}


struct RequestMessageView: View {
    
    let request: RequestMessageInfo
    
    let approve: (() -> Void)?
    let reject: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            AsyncImage(
                url: URL(string: request.iconURL),
                content: { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 80, maxHeight: 80)
                },
                placeholder: {
                    ProgressView()
                }
            )
            .padding(.top, 40)
            
            Text(request.name).font(.title).bold()
            Text(request.dappURL).font(.body).foregroundColor(.secondary)
//            Text(request.descriptionText).font(.body).foregroundColor(.gray)
//            Text(request.data).font(.body).foregroundColor(.gray)
            
            List {
                
                Section("Message") {
                    Text(String(data: Data(request.message.hexValue), encoding: .utf8) ?? "").font(.body).foregroundColor(.gray)
                }.headerProminence(.increased)
            }
            
            Spacer()
            HStack(alignment: .center, spacing: 12) {
                Button {
                    reject?()
                } label: {
                    Label("Reject", systemImage: "xmark.app.fill")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .cornerRadius(12)
                
                
                Button {
                    approve?()
                } label: {
                    Label("Approve", systemImage: "checkmark.square.fill")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

struct RequestMessageView_Previews: PreviewProvider {
    static var previews: some View {
        RequestMessageView(request: RequestMessageInfo(
            name: "Test",
            descriptionText: "descriptionText",
            dappURL: "https://test.com",
            iconURL: "https://github.com/Outblock/Assets/blob/main/ft/flow/logo.png?raw=true",
            chains: Set([Blockchain("flow:tetsnet")!]),
            methods: ["method_1", "method_2"],
            pendingRequests: ["1321"],
            message: "112321"),
                    approve: nil,
                    reject: nil
        )
    }
}

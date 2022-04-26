//
//  ContentView.swift
//  WCWallet
//
//  Created by Hao Fu on 27/2/2022.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject
    var viewModel:ViewModel
    
    @State
    var showQRScan: Bool = false
    
    @FocusState
    private var isFocused: Bool
    
    @State
    private var isScanned: Bool = false
    
    
//    init() {
//        viewModel.setup()
//    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Enter the WC link") {
                    TextField("wc://...", text: $viewModel.link)
                        .focused($isFocused)
                    Button("Connect") {
                        viewModel.connect()
                        isFocused = false
                    }
                }
                
                Section {
                    Button {
                        showQRScan = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                }
                
                Section("Connected") {
                    List{
                        ForEach(viewModel.sessionItems) { item in
                            HStack {
                                AsyncImage(
                                    url: URL(string: item.iconURL),
                                    content: { image in
                                        image.resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: 35, maxHeight: 35)
                                    },
                                    placeholder: {
                                        ProgressView()
                                    }
                                )
                                
                                VStack(alignment: HorizontalAlignment.leading) {
                                    Text(item.dappName)
                                    Text(item.dappURL)
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                    
                                }
                                Spacer()
                                Button("Disconnect") {
                                    viewModel.disconnect(item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Flow x WalletConnect")
        }
        .sheet(isPresented: $viewModel.showPopUp, onDismiss: nil, content: {
            ApproveView(session: viewModel.currentSessionInfo!) {
                viewModel.didApproveSession()
            } reject: {
                viewModel.didRejectSession()
            }

        })
        .sheet(isPresented: $showQRScan) {
            isScanned = false
        } content: {
            ScanQRView { code in
                if !isScanned {
                    viewModel.link = code
                    viewModel.connect()
                }
                isFocused = false
                showQRScan = false
                isScanned = true
            }
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ViewModel())
    }
}
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
            
                Section("Pairing") {
                    List {
                        ForEach(viewModel.activePairings, id: \.topic) { pair in
                            HStack {
//                                AsyncImage(
//                                    url: URL(string: pair.peer!.icons[0]),
//                                    content: { image in
//                                        image.resizable()
//                                            .aspectRatio(contentMode: .fit)
//                                            .frame(maxWidth: 35, maxHeight: 35)
//                                    },
//                                    placeholder: {
//                                        ProgressView()
//                                    }
//                                )
//
                                VStack(alignment: HorizontalAlignment.leading) {
                                    Text(pair.topic)
                                    Text(pair.expiryDate.formatDate())
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                    
                                }
                                Spacer()
//                                Button("Disconnect") {
//                                    viewModel.disconnect(item)
//                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Flow x WalletConnect")
        }
        .sheet(isPresented: $viewModel.showPopUp, onDismiss: {
            viewModel.didRejectSession()
        }, content: {
            ApproveView(session: viewModel.currentSessionInfo!) {
                viewModel.didApproveSession()
            } reject: {
                viewModel.didRejectSession()
            }

        })
        .sheet(isPresented: $viewModel.showRequestPopUp, onDismiss: {
            viewModel.didRejectRequest()
        }, content: {
            RequestView(request: viewModel.currentRequestInfo!) {
                viewModel.didApproveRequest()
            } reject: {
                viewModel.didRejectRequest()
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


extension Date {
        func formatDate() -> String {
                let dateFormatter = DateFormatter()
            dateFormatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
            return dateFormatter.string(from: self)
        }
}

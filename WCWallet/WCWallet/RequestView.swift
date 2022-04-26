//
//  RequestView.swift
//  WCWallet
//
//  Created by Hao Fu on 28/2/2022.
//

import SwiftUI
import UIKit
import WalletConnect

//struct ScanQRView: UIViewControllerRepresentable {
//    
//    
//    let vc = RequestViewController()
//    var handleCode: (String) -> Void
//    
//    var onSign: (()->())?
//    var onReject: (()->())?
//    
//    func makeUIViewController(context: Context) -> ScannerViewController {
//        return vc
//    }
//
//    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
//        
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(vc: vc, handleCode: handleCode)
//    }
//
//    class Coordinator: NSObject, ScannerViewControllerDelegate {
//        var handleCode: (String) -> Void
//        init(vc: ScannerViewController, handleCode: @escaping (String) -> Void) {
//            self.handleCode = handleCode
//            super.init()
//            vc.delegate = self
//        }
//        
//        func didScan(_ code: String) {
//            handleCode(code)
//        }
//    }
//}

class RequestViewController: UIViewController {
    var onSign: (()->())?
    var onReject: (()->())?
    let sessionRequest: Request
    private let requestView = RequestView()

    init(_ sessionRequest: Request) {
        self.sessionRequest = sessionRequest
        super.init(nibName: nil, bundle: nil)
    }
    
    override func loadView() {
        view = requestView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        requestView.approveButton.addTarget(self, action: #selector(signAction), for: .touchUpInside)
        requestView.rejectButton.addTarget(self, action: #selector(rejectAction), for: .touchUpInside)
        requestView.nameLabel.text = sessionRequest.method
        requestView.descriptionLabel.text = getParamsDescription()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func signAction() {
        onSign?()
        dismiss(animated: true)
    }
    
    @objc
    private func rejectAction() {
        onReject?()
        dismiss(animated: true)
    }
    
    private func getParamsDescription() -> String {
        let method = sessionRequest.method
//        if method == "personal_sign" {
//            return try! sessionRequest.params.get([String].self).description
//        } else if method == "eth_signTypedData" {
//            return try! sessionRequest.params.get([String].self).description
//        } else if method == "eth_sendTransaction" {
//            let params = try! sessionRequest.params.get([EthereumTransaction].self)
//            return params[0].description
//        }
//        fatalError("not implemented")
        
        return ""
    }
}

final class RequestView: UIView {
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .heavy)
        return label
    }()
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    let approveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sign", for: .normal)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        return button
    }()
    
    let rejectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reject", for: .normal)
        button.backgroundColor = .systemRed
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        return button
    }()
    
    let headerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        return stackView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        
        addSubview(headerStackView)
        addSubview(approveButton)
        addSubview(rejectButton)
        headerStackView.addArrangedSubview(nameLabel)
        headerStackView.addArrangedSubview(descriptionLabel)
        
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            
            headerStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 32),
            headerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            headerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
    
            
            approveButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            approveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            approveButton.heightAnchor.constraint(equalToConstant: 44),
            
            rejectButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            rejectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rejectButton.heightAnchor.constraint(equalToConstant: 44),
            
            approveButton.widthAnchor.constraint(equalTo: rejectButton.widthAnchor),
            rejectButton.leadingAnchor.constraint(equalTo: approveButton.trailingAnchor, constant: 16),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


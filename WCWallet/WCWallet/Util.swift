//
//  Util.swift
//  WCWallet
//
//  Created by Hao Fu on 7/6/2022.
//

import Foundation

extension String {
    /// Convert hex string to bytes
    var hexValue: [UInt8] {
        var startIndex = self.startIndex
        return (0 ..< count / 2).compactMap { _ in
            let endIndex = index(after: startIndex)
            defer { startIndex = index(after: endIndex) }
            return UInt8(self[startIndex ... endIndex], radix: 16)
        }
    }
}

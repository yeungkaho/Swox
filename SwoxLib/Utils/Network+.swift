//
//  Network+.swift
//  SwoxLib
//
//  Created by kahoyeung on 02/01/2024.
//

import Network

extension NWConnection {
    func tryCancel() {
        if state != .cancelled {
            cancel()
        }
    }
}

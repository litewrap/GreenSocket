//
//  main.swift
//  GreenSocket/SimpleUDPDemo
//
//  Created by Réjean Lamy on 2022-08-27.
//  Copyright © 2022 Réjean Lamy. All rights reserved.
//
//     Licensed under the Apache License, Version 2.0 (the "License");
//     you may not use this file except in compliance with the License.
//     You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//     Unless required by applicable law or agreed to in writing, software
//     distributed under the License is distributed on an "AS IS" BASIS,
//     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//     See the License for the specific language governing permissions and
//     limitations under the License.
//

import Foundation
import Socket

print("GreenSocket Simple UDP Demo")

do {
    let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
    let serverAddress = "127.0.0.1"
    let serverPort = 1337
    let serverFullAddress = Socket.createAddress(for: serverAddress, on: Int32(serverPort))

    try socket.listen(on: Int(serverPort))

    let msg1 = "Test Send String1"
    let msg2 = "Test Send String2"
    if let serverFullAddress = serverFullAddress {
        try socket.write(from: msg1, to: serverFullAddress)
        try socket.write(from: msg2, to: serverFullAddress)
    }

    var data = Data()
    var result = try socket.readDatagram(into: &data)

    print("bytesRead = \(result.bytesRead)")
    if result.bytesRead > 0 {
        let messageString = String(decoding: data, as: UTF8.self)
        print("Received message: \(messageString)")
    }

    data.removeAll()
    result = try socket.readDatagram(into: &data)

    print("bytesRead = \(result.bytesRead)")
    if result.bytesRead > 0 {
        let messageString = String(decoding: data, as: UTF8.self)
        print("Received message: \(messageString)")
    }

    socket.close()
    
    print("Simple UDP Demo")

}
catch {
    print("Socket error: \(error)")
}

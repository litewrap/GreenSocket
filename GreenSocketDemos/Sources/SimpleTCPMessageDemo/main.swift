//
//  main.swift
//  GreenSocket/SimpleTCPMessageDemo
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
#if os(Windows)
import WinSDK  // for msleep
#endif


//
// This extension add send / receive message methods - implementing a rudimentary message layer
// The message protocol has two parts: a 16-bit header followed by n-bytes payload
// The 16-bit header value represent the payload size in bytes
//
extension Socket {
    
    func sendMessage(data payload: Data, timeout: UInt) throws -> Int {
        let header  = UInt16(payload.count)
        let headerData = withUnsafeBytes(of: header.bigEndian) { bytes in Data(bytes) }
        return try self.write(from: headerData + payload)
    }
    
    func recvMessage(into data: inout Data, timeout: UInt) throws -> Int {
        // Read the header
        var headerData = Data()
        let headerCount = try self.read(into: &headerData, length: MemoryLayout<UInt16>.size, timeout: timeout)
        if headerCount > 0 {
            // Then read the payload
            // Compute the payload length from the header value
            let payloadLength = headerData.withUnsafeBytes { bytes in bytes.load(as: UInt16.self) }.bigEndian
            print("recvMessage: Received header: \(headerCount) bytes, value: \(payloadLength)")
            
            // Read the remaining payloadLength bytes
            print("recvMessage: Read remaining \(payloadLength) bytes...")
            return try self.read(into: &data, length: Int(payloadLength), timeout: timeout)
        }
        return 0
    }
}

var demoRunning = true
print("Swift SimpleTCPMessagDemo")

do {
    runServer()
    let serverAddress = "127.0.0.1"
    let serverPort = 1337
    let clientPort = 1338
    
    let socket = try Socket.create(family: .inet, type: .stream, proto: .tcp)
    defer {
        socket.close()
        print("SimpleTCPMessagDemo end")
    }
    try socket.listen(on: Int(clientPort))
    print("Client: Listening on port: \(clientPort)")
    try socket.connect(to: serverAddress, port: Int32(serverPort))
    
    let str = "Hello Swift World!"
    let data = str.data(using: .utf8)!
    let count = try socket.sendMessage(data: data, timeout: 5000)
    print("Client: \(count) bytes sent. 2 bytes header + \(str.count) bytes string: \"\(str)\"")
    
    repeat {
        msleep(milliseconds: 10)
    } while demoRunning
}
catch let error as Socket.ReadLengthError {
    print("Client: sendMessage error \(error)")
}
catch {
    print("Client: Something went wrong. Is Echo Server up and running on this machine ?")
    print("Client: error \(error)")
}

func runServer() {
    let queue = DispatchQueue(label: "serverworkqueue")
    queue.async {
        do {
            let listenSocket = try Socket.create(family: .inet)
            try listenSocket.listen(on: 1337)
            print("Server: Listening on port: \(1337)")
            let socket = try listenSocket.acceptClientConnection()
            
            defer {
                socket.close()
                listenSocket.close()
                print("Server: Stopped")
            }
            
            var data = Data()
            let count = try socket.recvMessage(into: &data, timeout: 5000)
            if count > 0 {
                if let msgReceived = String(data: data, encoding: .utf8) {
                    print("Server: \(count) bytes received string: \"\(msgReceived)\"")
                }
            }
        }
        catch let error as Socket.ReadLengthError {
            print("Server: read:length error \(error)")
        }
        catch {
            print("Server: error \(error)")
        }
        demoRunning = false
    }
}

func msleep(milliseconds: Int32) {

#if os(Windows)
WinSDK.Sleep(UInt32(milliseconds))
#else
    usleep(UInt32(milliseconds) * 1000)
#endif

}

//
//  main.swift
//  GreenSocket/EchoClientDemo
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

print("Swift Socket Echo Client Demo")
print("Start EchoServer in another session then run this client demo\n")

do {
    let socket = try Socket.create(family: .inet, type: .stream, proto: .tcp)
    defer {
        socket.close()
        print("Echo Client Demo end")
    }
    // if EchoServerDemo runs on another machine change serverAddress to the ipv4 server address
    let serverAddress = "127.0.0.1" // default to localhost
    let serverPort = 1337

    try socket.listen(on: Int(serverPort))
    try socket.connect(to: serverAddress, port: Int32(serverPort))
    
    let initialResponse = try socket.readString()
    if let response = initialResponse {
        print("Echo Server started and say:")
        print(response)
        print("")
    }
    repeat {
        print("Enter message to send or press RETURN key to quit:")
        if let line = readLine() {
            if line == "" { break }
            print("Client message: \(line)")
            let sentCount = try socket.write(from: line)
            if sentCount == 0 { break }
            var data = Data()
            let receiveCount = try socket.read(into: &data)
            if receiveCount == 0 {
                print("Server closed connection")
                break
            }
            if let response = String(data: data, encoding: .utf8) {
                print("Server respond: \(response)")
                if response == "QUIT" { break }
            }
        }
    } while true
}
catch {
    print("Something went wrong. Is Echo Server up and running on this machine ?")
    print("Socket error: \(error)")
}


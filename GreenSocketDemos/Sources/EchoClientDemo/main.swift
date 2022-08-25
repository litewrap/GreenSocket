//
// main.swift
// EchoClientDemo
//

import Foundation
import Socket

print("Swift Socket Echo Client Demo")
print("Start EchoServer in another session then run this client demo\n")

do {
    let socket = try Socket.create(family: .inet, type: .stream, proto: .tcp)
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
    
    socket.close()
    
    print("Echo Client Demo end")
}
catch {
    print("Something went wrong. Is Echo Server up and running on this machine ?")
    print("Socket error: \(error)")
}


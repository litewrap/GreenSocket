//
//  SocketUtils.swift
//  BlueSocket
//
//  Created by Bill Abt on 11/19/15.
//  Copyright © 2016 IBM. All rights reserved.
//
//  Modified by Réjean Lamy on 2022/08/24
//  Copyright © 2022 Réjean Lamy. All rights reserved.
//
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

#if os(macOS) || os(iOS) || os(tvOS)
import Darwin
#elseif os(Linux)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

import Foundation

//
// Great help with this from
// https://blog.obdev.at/representing-socket-addresses-in-swift-using-enums/
//
extension Socket.Address {
    
    ///
    /// Call a low level socket function using the specified socket address pointer.
    ///
    /// - Parameters:
    ///        - body:        The closure containing the call to the low level function.
    ///
    ///    - Returns:        The result of executing the closure.
    ///
    func withSockAddrPointer<Result>(body: (UnsafePointer<sockaddr>, socklen_t) throws -> Result) rethrows -> Result {
        
        ///
        /// Internal function to call do the cast and call to the closure.
        ///
        /// - Parameter:    Closure body.
        ///
        ///    - Returns:        Result of executing the closure.
        ///
        func castAndCall<T>(_ address: T, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> Result) rethrows -> Result {
            var localAddress = address // We need a `var` here for the `&`.
            return try withUnsafePointer(to: &localAddress) {
                return try $0.withMemoryRebound(to: sockaddr.self, capacity: 1, {
                    return try body($0, socklen_t(MemoryLayout<T>.size))
                })
            }
        }
        
        switch self {
            
        case .ipv4(let address):
            return try castAndCall(address, body)
            
        case .ipv6(let address):
            return try castAndCall(address, body)
            
        case .unix(let address):
            return try castAndCall(address, body)
            
        }
    }
}

extension Socket.Address {
    
    ///
    /// Creates a Socket.Address
    ///
    /// - Parameters:
    ///        - addressProvider:    Tuple containing pointers to the sockaddr and its length.
    ///
    ///    - Returns:                Newly initialized Socket.Address.
    ///
    init?(addressProvider: (UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) throws -> Void) rethrows {
        
        var addressStorage = sockaddr_storage()
        var addressStorageLength = socklen_t(MemoryLayout.size(ofValue: addressStorage))
        try withUnsafeMutablePointer(to: &addressStorage) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { addressPointer in
                try withUnsafeMutablePointer(to: &addressStorageLength) { addressLengthPointer in
                    try addressProvider(addressPointer, addressLengthPointer)
                }
            }
        }
        
        switch Int32(addressStorage.ss_family) {
        case AF_INET:
            self = withUnsafePointer(to: &addressStorage) {
                return $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    return Socket.Address.ipv4($0.pointee)
                }
            }
        case AF_INET6:
            self = withUnsafePointer(to: &addressStorage) {
                return $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    return Socket.Address.ipv6($0.pointee)
                }
            }
        case AF_UNIX:
            self = withUnsafePointer(to: &addressStorage) {
                return $0.withMemoryRebound(to: sockaddr_un.self, capacity: 1) {
                    return Socket.Address.unix($0.pointee)
                }
            }
        default:
            return nil
        }
    }
}

 #if os(Linux)

     // fd_set array access for Linux

    /// Arm archictecture only allows for 16 fds.
    #if arch(arm)
        let __fd_set_count = 16
    #else
        let __fd_set_count = 32
    #endif

    extension fd_set {
    
        @inline(__always)
        mutating func withCArrayAccess<T>(block: (UnsafeMutablePointer<Int32>) throws -> T) rethrows -> T {
            return try withUnsafeMutablePointer(to: &__fds_bits) {
                try block(UnsafeMutableRawPointer($0).assumingMemoryBound(to: Int32.self))
            }
        }
    }

#elseif os(Windows)

// fd_set array access for Windows

let fd_set_size = 64

extension fd_set {

    @inline(__always)
    mutating func withCArrayAccess<T>(block: (UnsafeMutablePointer<Int32>) throws -> T) rethrows -> T {
        return try withUnsafeMutablePointer(to: &fd_array) {
            try block(UnsafeMutableRawPointer($0).assumingMemoryBound(to: Int32.self))
        }
    }
}

#else

    // fd_set array access for macOS, iOS...

    // __DARWIN_FD_SETSIZE is number of *bits*, so divide by number bits in each element to get element count
    // at present this is 1024 / 32 == 32
    let __fd_set_count = Int(__DARWIN_FD_SETSIZE) / 32

    extension fd_set {
    
        @inline(__always)
        mutating func withCArrayAccess<T>(block: (UnsafeMutablePointer<Int32>) throws -> T) rethrows -> T {
            return try withUnsafeMutablePointer(to: &fds_bits) {
                try block(UnsafeMutableRawPointer($0).assumingMemoryBound(to: Int32.self))
            }
        }
    }

#endif

#if os(Windows)

// fd_set extension for Windows
// functions zero, set, clear, isSet

extension fd_set {
        
    ///
    /// Zero the fd_set
    ///
    public mutating func zero() {
        withCArrayAccess { arrayPtr in arrayPtr.initialize(repeating: 0, count: fd_set_size) }
        fd_count = 0
    }
        
    ///
    /// Set an fd in an fd_set
    ///
    /// - Parameter fd:    The fd to add to the fd_set
    ///
    public mutating func set(_ fd: Int32) {
        var local_fd_count = fd_count
        var index = 0
        withCArrayAccess { arrayPtr in
            for _ in 0..<Int(local_fd_count) {
                if arrayPtr[index] == fd {  break }
                index += 1
            }
            if index == local_fd_count {
                if local_fd_count < fd_set_size {
                    arrayPtr[index] = fd
                    local_fd_count += 1
                }
            }
            //print("index \(index) local_fd_count \(local_fd_count)")
        }
        fd_count = local_fd_count
        //print("fd_count \(fd_count)")
    }
        
    ///
    /// Clear an fd from an fd_set
    ///
    /// - Parameter fd:    The fd to clear from the fd_set
    ///
    public mutating func clear(_ fd: Int32) {
        var local_fd_count = fd_count
        withCArrayAccess { arrayPtr in
            for var i in 0..<Int(local_fd_count) {
                if arrayPtr[i] == fd {
                    //print("clear found at index \(i)")
                    while i < fd_set_size - 1 {
                        arrayPtr[i] =  arrayPtr[i + 1]
                        i += 1
                    }
                    local_fd_count -= 1
                    break
                }
            }
        }
        fd_count = local_fd_count
        //print("fd_count \(fd_count)")
    }
    
    ///
    /// Check if an fd is present in an fd_set
    ///
    /// - Parameter fd:    The fd to check
    ///
    ///    - Returns:    `True` if present, `false` otherwise.
    ///
    public mutating func isSet(_ fd: Int32) -> Bool {
        let local_fd_count = fd_count
        return withCArrayAccess { arrayPtr in
            for i in 0..<Int(local_fd_count) {
                if arrayPtr[i] == fd {
                    return true
                }
            }
            return false
        }
    }
}

#else

// fd_set extension for Linux and macOS, iOS..
// functions zero, set, clear, isSet

extension fd_set {
    
    @inline(__always)
    private static func address(for fd: Int32) -> (Int, Int32) {
        var intOffset = Int(fd) / __fd_set_count
        #if _endian(big)
        if intOffset % 2 == 0 {
            intOffset += 1
        } else {
            intOffset -= 1
        }
        #endif
        let bitOffset = Int(fd) % __fd_set_count
        let mask = Int32(bitPattern: UInt32(1 << bitOffset))
        return (intOffset, mask)
    }
    
    ///
    /// Zero the fd_set
    ///
    public mutating func zero() {
        #if swift(>=4.1)
        withCArrayAccess { $0.initialize(repeating: 0, count: __fd_set_count) }
        #else
        withCArrayAccess { $0.initialize(to: 0, count: __fd_set_count) }
        #endif
    }
    
    ///
    /// Set an fd in an fd_set
    ///
    /// - Parameter fd:    The fd to add to the fd_set
    ///
    public mutating func set(_ fd: Int32) {
        let (index, mask) = fd_set.address(for: fd)
        withCArrayAccess { $0[index] |= mask }
    }
    
    ///
    /// Clear an fd from an fd_set
    ///
    /// - Parameter fd:    The fd to clear from the fd_set
    ///
    public mutating func clear(_ fd: Int32) {
        let (index, mask) = fd_set.address(for: fd)
        withCArrayAccess { $0[index] &= ~mask }
    }
    
    ///
    /// Check if an fd is present in an fd_set
    ///
    /// - Parameter fd:    The fd to check
    ///
    ///    - Returns:    `True` if present, `false` otherwise.
    ///
    public mutating func isSet(_ fd: Int32) -> Bool {
        let (index, mask) = fd_set.address(for: fd)
        return withCArrayAccess { $0[index] & mask != 0 }
    }
}
#endif

#if os(Windows)
extension in_addr {
    public mutating func zero() {
        self.S_un.S_addr = 0
        self.S_un.S_un_b.s_b1 = 0
        self.S_un.S_un_b.s_b2 = 0
        self.S_un.S_un_b.s_b3 = 0
        self.S_un.S_un_b.s_b4 = 0
        self.S_un.S_un_w.s_w1 = 0
        self.S_un.S_un_w.s_w2 = 0
    }
}
#endif

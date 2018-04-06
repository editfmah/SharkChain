//    MIT License
//
//    Copyright (c) 2018 SharkChain Team
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

import Foundation

class Config {
    
    static let CurrencyName = "SharkCoin"
    static let CurrencyNetworkAddress = "53524b"
    
    // number by which token value is divided to determine currency value
    static let DenominationDivider = 100
    
    // regularity of block creation
    static let BlockTime = 60
    
    // size of the ore segment in megabytes - 1mb gives posibilities of 1.169e^57 combinations @ address size of 8
    static let OreSize = 1
    
    // release schedule of an ore segment
    static let OreReleasePoint = 250000 // 250000 = approximately 2 blocks per year
    
    static let TokenSegmentSize = 64
    
    // number of addresses within the block that makes up a token address, exponentially increses ore payload
    static let TokenAddressSize = 8
    
    // seed nodes
    static let SeedNodes: [String] = []
    
}

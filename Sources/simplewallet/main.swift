//    MIT License
//
//    Copyright (c) 2018 Veldspar Team
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
import VeldsparCore
import Ed25519
import CryptoSwift

#if os(Linux)
srandom(UInt32(time(nil)))
#endif

// default values
var currentPassword: String?
var currentFilename: String?
var walletOpen = false
var wallet: WalletFile?
let walletLock = Mutex()
var node = "127.0.0.1:14242"
var isTestNet = false

// the choice switch

enum WalletAction {
    
    case ShowOptions
    case Open
    case Create
    case Transactions
    case Exit
    case Balance
    
}

var currentAction: WalletAction = .ShowOptions

let args: [String] = CommandLine.arguments

if args.count > 1 {
    for i in 1...args.count-1 {
        
        let arg = args[i]
        
        if arg.lowercased() == "--help" {
            print("\(Config.CurrencyName) - Wallet - v\(Config.Version)")
            print("-----   COMMANDS -------")
            print("--walletfile          : specifies the name of the wallet to open")
            print("--password            : the password to decrypt the wallet")
            print("--debug               : enables debugging output")
            print(" ")
            exit(0)
        }
        if arg.lowercased() == "--debug" {
            debug_on = true
        }
        if arg.lowercased() == "--testnet" {
            isTestNet = true
        }
        if arg.lowercased() == "--walletfile" {
            
            if i+1 < args.count {
                
                let add = args[i+1]
                currentFilename = add
                
            }
            
        }
        
        if arg.lowercased() == "--password" {
            
            if i+1 < args.count {
                
                let t = args[i+1]
                currentPassword = t
                
            }
            
        }
        
        if arg.lowercased() == "--node" {
            
            if i+1 < args.count {
                
                let t = args[i+1]
                node = t
                
            }
            
        }
        
    }
}

print("---------------------------")
print("\(Config.CurrencyName) Wallet v\(Config.Version)")
print("---------------------------")

if currentPassword != nil && currentFilename != nil {
    
    // now try and open/decrypt the wallet object
    walletLock.mutex {
        let w =  WalletFile(currentFilename!, password: currentPassword!)
        if w.isDecodable() {
            
            wallet = w
            walletOpen = true
            print("")
            print("Wallet opened containing addresses:")
            for a in wallet!.addresses() {
                print(a)
            }
            
        } else {
            print("incorrect password")
            exit(0)
        }
        
    }
    
}

func WalletLoop() {
    
    while true {
        
        var delay = 10.0
        
        walletLock.mutex {
            
            // fetch the current height
            if walletOpen && wallet != nil {
                
                let nwHeight = try? Data(contentsOf: URL(string:"http://\(node)/currentheight")!)
                if nwHeight != nil {
                    let height = try? JSONDecoder().decode(CurrentHeightObject.self, from: nwHeight!)
                    
                    if wallet!.height() < height!.height! {
                        
                        let nextHeight = wallet!.height() + 1
                        
                        let blockData = try? Data(contentsOf: URL(string:"http://\(node)/block?height=\(nextHeight)")!)
                        if blockData != nil {
                            
                            let b = try? JSONDecoder().decode(Block.self, from: blockData!)
                            if b != nil {
                                let block = b!
                                var totalAdded = 0
                                var totalSpent = 0
                                
                                for l in block.transactions ?? [] {
                                    
                                    totalAdded += wallet?.addTokenIfOwned(l) ?? 0
                                    totalSpent += wallet?.removeTokenIfOwned(l) ?? 0
                                    
                                }
                                
                                print("processing block \(block.height!) of \(height!.height!)")
                                
                                if totalAdded > 0 || totalSpent > 0 {
                                    
                                    print("\((Float(totalAdded) / Float(Config.DenominationDivider))) \(Config.CurrencyName) added to wallet.")
                                    print("Value of spent tokens: \((Float(totalSpent) / Float(Config.DenominationDivider)))")
                                    print("--------------------------")
                                    print("Current balance: \(wallet!.balance())")
                                    
                                }
                                
                                if block.height != nil {
                                    wallet?.setHeight(Int(block.height!))
                                }
                                
                                delay = 0.0
                                
                            } else {
                                
                                delay = 10.0
                                
                            }
                            
                        }
                        
                        
                    } else {
                        
                        delay = 60.0
                        
                    }
                    
                }

            }
        }
        Thread.sleep(forTimeInterval: delay)
    }
}

Execute.background {
    WalletLoop()
}

while true {
    
    while true {
        
        if walletOpen == false {
            
            SimpleMenu(["O" : "Open existing wallet", "N" : "Create new wallet","R" : "Restore wallet", "X" : "Exit"])
            let answer = readLine()
            switch answer?.lowercased() ?? "" {
            case "o":
                
                print("filename ? (e.g. 'mywallet')")
                let filename = readLine()
                if filename == nil || filename!.count < 1 {
                    print("ERROR: invalid filename")
                    break;
                }
                
                print("password ?")
                let password = readLine()
                if password == nil || password!.count < 1 {
                    print("ERROR: invalid password")
                    break;
                }
                
                // now try and open/decrypt the wallet object
                walletLock.mutex {
                    let w = WalletFile(filename!, password: password!)
                    if w.isDecodable() {
                        wallet = w
                        currentPassword = password
                        currentFilename = filename
                        walletOpen = true
                        print("")
                        print("Wallet opened containing addresses:")
                        for a in w.addresses() {
                            print(a)
                        }
                        
                        ShowOpenedMenu()
                        
                    } else {
                        print("incorrect password")
                    }
                }
                
            case "n":
                
                print("filename ? (e.g. 'mywallet')")
                let filename = readLine()
                if filename == nil || filename!.count < 1 {
                    print("ERROR: invalid filename")
                    break;
                }
                
                print("password ?")
                let password = readLine()
                if password == nil || password!.count < 1 {
                    print("ERROR: invalid password")
                    break;
                }
                
                print("confirm password ?")
                let password2 = readLine()
                if password2 == nil || password2!.count < 1 {
                    print("ERROR: invalid password")
                    break;
                }
                if password! != password2! {
                    print("ERROR: passwords did not match")
                    break;
                }
                
                walletLock.mutex {
                    
                    wallet = WalletFile(filename!, password: password!)
                    let address = try? wallet!.createNewAddress()
                    currentFilename = filename
                    currentPassword = password
                    walletOpen = true
                    
                    print("")
                    print("Wallet created, please record the information below somewhere secure.")
                    
                    print("address: \(address ?? "")")
                    print("seed uuid: \(wallet!.seedForAddress(address!) ?? "")")
                    print("")
                    print("current balance: \(wallet!.balance())")
                    
                    ShowOpenedMenu()
                    
                }
                
            case "r":
                
                print("seed uuid ? (e.g. '82B27DE0-0FA8-4D86-9C7B-ACAA5424AC0F-82B27DE0-0FA8-4D86-9C7B-ACAA5424AC0F')")
                let uuid = readLine()
                if uuid == nil || uuid!.count < 36 {
                    print("ERROR: invalid seed uuid")
                    break;
                }
                
                print("filename ? (e.g. 'mywallet')")
                let filename = readLine()
                if filename == nil || filename!.count < 1 {
                    print("ERROR: invalid filename")
                    break;
                }
                
                print("password ?")
                let password = readLine()
                if password == nil || password!.count < 1 {
                    print("ERROR: invalid password")
                    break;
                }
                
                print("confirm password ?")
                let password2 = readLine()
                if password2 == nil || password2!.count < 1 {
                    print("ERROR: invalid password")
                    break;
                }
                if password! != password2! {
                    print("ERROR: passwords did not match")
                    break;
                }
                
                walletLock.mutex {
                    
                    wallet = WalletFile(filename!, password: password!)
                    let address = try? wallet!.addExistingAddress(uuid!)
                    currentFilename = filename
                    currentPassword = password
                    walletOpen = true
                    
                    print("")
                    print("Wallet restored, please record the information below somewhere secure.")
                    
                    print("address: \(address ?? "")")
                    print("seed uuid: \(uuid!)")
                    print("")
                    print("current balance: \(wallet!.balance())")
                    
                    ShowOpenedMenu()
                    
                }
                
            case "x":
                exit(0)
            default:
                break;
            }
            
        } else {
            
            // wallet open
            
            let answer = readLine()
            switch answer?.lowercased() ?? "" {
            case "b":
                print("")
                print("current balance: \(wallet!.balance())")
            case "l":
                print("feature not implemented yet")
            case "p":
                print("feature not implemented yet")
            case "t":
                
                // transfer tokens to anotehr address
                
                
            case "c": // create new
                
                let uuid = UUID().uuidString.lowercased() + "-" + UUID().uuidString.lowercased()
                let address = try? wallet!.addExistingAddress(uuid)
                print("")
                print("Wallet created, please record the information below somewhere secure.")
                
                print("address: \(address ?? "")")
                print("seed uuid: \(uuid)")
                print("")
                print("current balance: \(wallet!.balance())")
                
                ShowOpenedMenu()
                
            case "a": // add existing
                
                print("seed uuid ? (e.g. '82B27DE0-0FA8-4D86-9C7B-ACAA5424AC0F-82B27DE0-0FA8-4D86-9C7B-ACAA5424AC0F')")
                let uuid = readLine()
                if uuid == nil || uuid!.count < 36 {
                    print("ERROR: invalid seed uuid")
                    break;
                }
                
                
                walletLock.mutex {
                    
                    let address = try? wallet!.addExistingAddress(uuid!)
                    
                    print("")
                    print("Wallet restored, please record the information below somewhere secure.")
                    
                    print("address: \(address ?? "")")
                    print("seed uuid: \(wallet?.seedForAddress(address!) ?? "")")
                    print("")
                    print("current balance: \(wallet!.balance())")
                    
                    ShowOpenedMenu()
                    
                }
                
            case "d": // delete
                
                print("Choose address to delete")
                ListWallets()
                
                let choice = readLine()
                if choice == nil {
                    ShowOpenedMenu()
                    break
                }
                
                if Int(choice!) == nil {
                    ShowOpenedMenu()
                    break
                }
                
                if Int(choice!)! > wallet!.addresses().count {
                    ShowOpenedMenu()
                    break
                }
                
                wallet?.deleteAddress(wallet!.addresses()[Int(choice!)!-1])
                ShowOpenedMenu()
                break
                
            case "w": // list wallets
                ListWallets()
            case "n": // name wallet
                
                print("Choose wallet to rename")
                ListWallets()
                
                let choice = readLine()
                if choice == nil {
                    ShowOpenedMenu()
                    break
                }
                
                if Int(choice!) == nil {
                    ShowOpenedMenu()
                    break
                }
                
                if Int(choice!)! > wallet!.addresses().count {
                    ShowOpenedMenu()
                    break
                }
                
                let w = wallet!.addresses()[Int(choice!)!-1]
                
                print("new name ?")
                
                let newName = readLine()
                if newName != nil && newName!.count > 0 {
                    wallet!.nameAddress(w, name: newName!)
                }
                
                ShowOpenedMenu()
                break
                
            case "r":
                
                print("Rebuilding wallet, a full re-sync will now take place.")
                
                walletLock.mutex {
                    
                    wallet!.setHeight(0)
                    
                }
                
            case "x":
                exit(0)
            case "s":
                walletLock.mutex {
                    
                    for w in wallet!.addresses() {
                        print("seed for address \(w) is \(wallet!.seedForAddress(w) ?? "")")
                    }
                    
                }
            case "h":
                ShowOpenedMenu()
            case "help":
                ShowOpenedMenu()
            default:
                ShowOpenedMenu()
            }
            
        }
        
    }
    
}



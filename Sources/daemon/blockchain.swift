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

enum BlockchainErrors : Error {
    case TokenHasNoValue
    case InvalidAddress
    case InvalidAlgo
    case InvalidToken
}

class BlockChain {
    
    private let blockchain_lock: Mutex
    private let stats_lock: Mutex
    private var current_tidemark: Block?
    private var current_height: Int?
    
    init() {
        
        blockchain_lock = Mutex()
        stats_lock = Mutex()
        
    }
    
    func nodes() -> [PeeringNode] {
        
        var retValue: [PeeringNode] = []
        
        blockchain_lock.mutex {
            retValue = Database.PeeringNodes()
        }
        
        return retValue
        
    }
    
    func putNodes(_ nodes: [PeeringNode]) {
        
        blockchain_lock.mutex {
            Database.WritePeeringNodes(nodes: nodes)
        }
        
    }
    
    func purgeStaleNodes() {
        
        blockchain_lock.mutex {
            let max = UInt64(Date().timeIntervalSince1970 * 1000) - 120000
            _ = db.execute(sql: "DELETE FROM PeeringNode WHERE lastcomm < ?", params: [max])
        }
        
    }
    
    func putNode(_ node: PeeringNode) {
        
        blockchain_lock.mutex {
            Database.WritePeeringNodes(nodes: [node])
        }
        
    }
    
    func setNewHeight(_ newHeight: Int) {
        
        stats_lock.mutex {
            current_height = newHeight
        }
        
    }
    
    func height() -> Int {
        
        var count: Int = -1
        
        stats_lock.mutex {
            if current_height != nil {
                count = current_height!
            }
        }
        
        if count != -1 {
            return count
        }
        
        blockchain_lock.mutex {
            
            // query the database to find the highest block there is
            count = Database.CurrentHeight() ?? -1
            stats_lock.mutex {
                current_height = Int(count)
            }
            
        }
        
        // could legitimately still be zero of course.
        return count
        
    }
    
    func removeBlockAtHeight(_ height: Int) -> Bool {
        
        var ret = false;
        
        blockchain_lock.mutex {
            ret = Database.DeleteBlock(height)
        }
        
        return ret
        
    }
    
    func blockAtHeight(_ height: Int, includeTransactions: Bool) -> Block? {
        
        var block: Block? = nil
        
        blockchain_lock.mutex {
            // query database
            block = Database.BlockAtHeight(height, includeTransactions: includeTransactions)
        }
        
        return block
        
    }
    
    func LedgersForBlock(_ height: Int) -> [Ledger] {
        
        var ledgers: [Ledger] = []
        
        blockchain_lock.mutex {
            ledgers = Database.LedgersForHeight(height)
        }
        
        return ledgers
        
    }
    
    func addBlock(_ block:Block) -> Bool {
        
        var retValue = false
        
        blockchain_lock.mutex {
            
            if block.height! > height() {
                retValue = Database.WriteBlock(block)
                if retValue {
                    setNewHeight(Int(block.height!))
                }
            }
            
        }
        
        return retValue
        
    }
    
    func setTransactionStateForHeight(height: Int, state: LedgerTransactionState) {
        
        blockchain_lock.mutex {
            Database.SetTransactionStateForHeight(height: height, state: state)
        }
        
    }

    
    // ledger functions
    
    func commitLedgerItems(tokens: [Ledger], failIfAny: Bool) -> Bool {
        
            var retValue = true
            
            blockchain_lock.mutex {
                
                if Database.CommitLedger(ledgers: tokens, failAll: failIfAny) {
                    
                    retValue = true
                    
                } else {
                    // failed the verify
                    retValue = false
                }
                
            }
            
            return retValue

    }
    
    func tokenOwnership(token: String) -> [Ledger] {
        
        var l: [Ledger] = []
        
        do {
            let t = try Token(token)

            blockchain_lock.mutex {
                l = Database.TokenOwnershipRecord(ore: t.oreHeight, address: t.address)
            }

        } catch {
            return []
        }
        
        return l;
        
    }
    
    func registerToken(tokenString: String, address: String, bean: String, block: Int) throws -> Bool {
        
        var returnValue = false
        var token = tokenString
        var t: Token?
        
        // first off, check that the token is essentially valid in construction
        // 0-1-32-00018467-00043A62-0006F243
        let components = token.components(separatedBy: "-")
        if components.count != 4 {
            throw BlockchainErrors.InvalidToken
        }
        
        do {
            t = try Token(token)
        } catch {
            throw BlockchainErrors.InvalidToken
        }
        
        if AlgorithmManager.sharedInstance().depricated(type: t!.algorithm, height: UInt(t!.oreHeight)) {
            logger.log(level: .Warning, log: "(BlockChain) token submitted to 'registerToken(token: String, address: String, block: Int) -> Bool' was of deprecated method.")
            throw BlockchainErrors.InvalidAlgo
        }
        
        // create the ledger
        let l = Ledger()
        l.op = LedgerOPType.RegisterToken.rawValue
        l.address = t!.address
        l.height = block
        l.algorithm = t!.algorithm.rawValue
        l.date = UInt64(consensusTime())
        l.destination = Crypto.strAddressToData(address: address)
        l.ore = t!.oreHeight
        l.state = LedgerTransactionState.Pending.rawValue
        l.transaction_id = Data(bytes: UUID().uuidString.bytes.sha224())
        l.source = Crypto.strAddressToData(address: address)
        l.value = t!.value()
        l.bean = bean.hexToData
        l.hash = l.checksum()
        
        var success = false;
        
        // the atomicity & validity of the ledger will be checked by the data layer upon submission
        blockchain_lock.mutex {
            success = Database.CommitLedger(ledgers: [l], failAll: true)
        }
        
        if success {
            
            logger.log(level: .Warning, log: "(BlockChain) token submitted to 'registerToken(token: String, address: String, block: Int) -> Bool' call to 'Database.WritePendingLedger()' succeeded, token written.")
            
            // now broadcast this transaction to the connected nodes
            broadcaster.add([l])
            
            return true
            
        } else {
            
            if t!.value() == 0 {
                logger.log(level: .Warning, log: "(BlockChain) token submitted to 'registerToken() -> Bool' was invalid and has no value.")
                throw BlockchainErrors.TokenHasNoValue
            }
            
            logger.log(level: .Warning, log: "(BlockChain) token submitted to 'registerToken(token: String, address: String, block: Int) -> Bool' this token exists already in blockchain.db")
            
        }
        
        return false
        
    }
    
    func transferToken(token: String, address: String, block: Int, auth: String, reference: String) -> Bool {
        
        let returnValue = false
        
//        // validate the token
//        do {
//            let t = try Token(address)
//            if t.value() == 0 {
//                return false
//            }
//        } catch {
//            return false
//        }
//
//        lock.mutex {
//
//            if Database.TokenOwnershipRecord(token) == nil && Database.TokenPendingRecord(token) == nil {
//
//                let l = Ledger(op: .ChangeOwner, token: token, ref: reference, address: address, auth: auth, block: block)
//                if Database.WritePendingLedger(l) == true {
//                    returnValue = true
//                }
//
//            }
//
//        }
        
        return returnValue
        
    }
    
    
}

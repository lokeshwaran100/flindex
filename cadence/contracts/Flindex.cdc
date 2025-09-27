import "FungibleToken"
import "FlowToken"

/// Flindex - Decentralized Crypto Index Fund Platform
/// A platform for creating and managing crypto index funds with fixed 50-50 TRUMP/USDF composition
access(all) contract Flindex {
    
    // Token addresses for TRUMP and USDF on Flow EVM
    access(all) let TRUMP_ADDRESS: Address
    access(all) let USDF_ADDRESS: Address
    
    // Storage paths
    access(all) let IndexStoragePath: StoragePath
    access(all) let IndexPublicPath: PublicPath
    
    // Events
    access(all) event IndexCreated(indexId: UInt64, creator: Address)
    access(all) event IndexPurchased(indexId: UInt64, user: Address, flowAmount: UFix64, trumpAmount: UFix64, usdfAmount: UFix64)
    access(all) event IndexSold(indexId: UInt64, user: Address, shareAmount: UFix64, flowReceived: UFix64)
    
    // Index information structure
    access(all) struct IndexInfo {
        access(all) let indexId: UInt64
        access(all) let creator: Address
        access(all) let totalFlowInvested: UFix64
        access(all) let totalTrumpHeld: UFix64
        access(all) let totalUsdfHeld: UFix64
        access(all) let isActive: Bool
        
        init(indexId: UInt64, creator: Address) {
            self.indexId = indexId
            self.creator = creator
            self.totalFlowInvested = 0.0
            self.totalTrumpHeld = 0.0
            self.totalUsdfHeld = 0.0
            self.isActive = true
        }
    }
    
    // User's index holdings
    access(all) struct UserIndexHoldings {
        access(all) let indexId: UInt64
        access(all) let flowInvested: UFix64
        access(all) let trumpShare: UFix64
        access(all) let usdfShare: UFix64
        
        init(indexId: UInt64, flowInvested: UFix64, trumpShare: UFix64, usdfShare: UFix64) {
            self.indexId = indexId
            self.flowInvested = flowInvested
            self.trumpShare = trumpShare
            self.usdfShare = usdfShare
        }
    }
    
    // Index resource for managing individual index funds
    access(all) resource Index {
        access(all) let indexId: UInt64
        access(all) let creator: Address
        access(all) var totalFlowInvested: UFix64
        access(all) var totalTrumpHeld: UFix64
        access(all) var totalUsdfHeld: UFix64
        access(all) var isActive: Bool
        
        // User holdings mapping
        access(all) var userHoldings: {Address: UserIndexHoldings}
        
        init(indexId: UInt64, creator: Address) {
            self.indexId = indexId
            self.creator = creator
            self.totalFlowInvested = 0.0
            self.totalTrumpHeld = 0.0
            self.totalUsdfHeld = 0.0
            self.isActive = true
            self.userHoldings = {}
        }
        
        // Add user investment to the index
        access(all) fun addInvestment(user: Address, flowAmount: UFix64, trumpAmount: UFix64, usdfAmount: UFix64) {
            pre {
                flowAmount > 0.0: "Flow amount must be positive"
                trumpAmount >= 0.0: "TRUMP amount must be non-negative"
                usdfAmount >= 0.0: "USDF amount must be non-negative"
            }
            
            self.totalFlowInvested = self.totalFlowInvested + flowAmount
            self.totalTrumpHeld = self.totalTrumpHeld + trumpAmount
            self.totalUsdfHeld = self.totalUsdfHeld + usdfAmount
            
            // Update or create user holdings
            if let existingHoldings = self.userHoldings[user] {
                let newHoldings = UserIndexHoldings(
                    indexId: self.indexId,
                    flowInvested: existingHoldings.flowInvested + flowAmount,
                    trumpShare: existingHoldings.trumpShare + trumpAmount,
                    usdfShare: existingHoldings.usdfShare + usdfAmount
                )
                self.userHoldings[user] = newHoldings
            } else {
                let newHoldings = UserIndexHoldings(
                    indexId: self.indexId,
                    flowInvested: flowAmount,
                    trumpShare: trumpAmount,
                    usdfShare: usdfAmount
                )
                self.userHoldings[user] = newHoldings
            }
        }
        
        // Remove user investment from the index
        access(all) fun removeInvestment(user: Address, shareAmount: UFix64): (UFix64, UFix64) {
            pre {
                shareAmount > 0.0: "Share amount must be positive"
            }
            
            if let holdings = self.userHoldings[user] {
                // Calculate proportional amounts to remove
                let trumpToRemove = (holdings.trumpShare * shareAmount) / holdings.flowInvested
                let usdfToRemove = (holdings.usdfShare * shareAmount) / holdings.flowInvested
                
                // Update totals
                self.totalFlowInvested = self.totalFlowInvested - shareAmount
                self.totalTrumpHeld = self.totalTrumpHeld - trumpToRemove
                self.totalUsdfHeld = self.totalUsdfHeld - usdfToRemove
                
                // Update user holdings
                let newFlowInvested = holdings.flowInvested - shareAmount
                let newTrumpShare = holdings.trumpShare - trumpToRemove
                let newUsdfShare = holdings.usdfShare - usdfToRemove
                
                if newFlowInvested <= 0.0 {
                    self.userHoldings.remove(key: user)
                } else {
                    let updatedHoldings = UserIndexHoldings(
                        indexId: self.indexId,
                        flowInvested: newFlowInvested,
                        trumpShare: newTrumpShare,
                        usdfShare: newUsdfShare
                    )
                    self.userHoldings[user] = updatedHoldings
                }
                
                return (trumpToRemove, usdfToRemove)
            } else {
                panic("User has no holdings in this index")
            }
        }
        
        // Get user holdings
        access(all) fun getUserHoldings(user: Address): UserIndexHoldings? {
            return self.userHoldings[user]
        }
        
        // Get index info
        access(all) fun getIndexInfo(): IndexInfo {
            return IndexInfo(
                indexId: self.indexId,
                creator: self.creator,
                totalFlowInvested: self.totalFlowInvested,
                totalTrumpHeld: self.totalTrumpHeld,
                totalUsdfHeld: self.totalUsdfHeld,
                isActive: self.isActive
            )
        }
    }
    
    // Global state
    access(all) var nextIndexId: UInt64
    access(all) var indexes: {UInt64: @Index}
    
    init() {
        self.TRUMP_ADDRESS = 0xd3378b419feae4e3a4bb4f3349dba43a1b511760
        self.USDF_ADDRESS = 0x2aabea2058b5ac2d339b163c6ab6f2b6d53aabed
        self.IndexStoragePath = /storage/flindexIndex
        self.IndexPublicPath = /public/flindexIndex
        self.nextIndexId = 1
        self.indexes = {}
    }
    
    // Create a new index fund
    access(all) fun createIndex(creator: Address): UInt64 {
        let indexId = self.nextIndexId
        self.nextIndexId = self.nextIndexId + 1
        
        let index <- create Index(indexId: indexId, creator: creator)
        self.indexes[indexId] <- index
        
        emit IndexCreated(indexId: indexId, creator: creator)
        
        return indexId
    }
    
    // Buy index shares with Flow tokens
    access(all) fun buyIndex(indexId: UInt64, user: Address, flowAmount: UFix64): (UFix64, UFix64) {
        pre {
            flowAmount > 0.0: "Flow amount must be positive"
        }
        
        if let index = self.indexes[indexId] {
            // Calculate 50-50 split for TRUMP and USDF
            let halfFlow = flowAmount / 2.0
            
            // In a real implementation, you would use SwapConnectors here
            // For now, we'll simulate the swap amounts
            // This would be replaced with actual swap logic using IncrementFiSwapConnectors
            
            // Simulate swap results (in real implementation, use actual swap connectors)
            let trumpAmount = halfFlow * 0.95 // Simulate 5% slippage
            let usdfAmount = halfFlow * 0.95  // Simulate 5% slippage
            
            index.addInvestment(user: user, flowAmount: flowAmount, trumpAmount: trumpAmount, usdfAmount: usdfAmount)
            
            emit IndexPurchased(indexId: indexId, user: user, flowAmount: flowAmount, trumpAmount: trumpAmount, usdfAmount: usdfAmount)
            
            return (trumpAmount, usdfAmount)
        } else {
            panic("Index not found")
        }
    }
    
    // Sell index shares back to Flow tokens
    access(all) fun sellIndex(indexId: UInt64, user: Address, shareAmount: UFix64): UFix64 {
        pre {
            shareAmount > 0.0: "Share amount must be positive"
        }
        
        if let index = self.indexes[indexId] {
            let (trumpToSell, usdfToSell) = index.removeInvestment(user: user, shareAmount: shareAmount)
            
            // In a real implementation, you would use SwapConnectors here to swap TRUMP and USDF back to Flow
            // For now, we'll simulate the conversion
            let flowReceived = trumpToSell + usdfToSell // Simplified calculation
            
            emit IndexSold(indexId: indexId, user: user, shareAmount: shareAmount, flowReceived: flowReceived)
            
            return flowReceived
        } else {
            panic("Index not found")
        }
    }
    
    // Get index information
    access(all) fun getIndexInfo(indexId: UInt64): IndexInfo? {
        if let index = self.indexes[indexId] {
            return index.getIndexInfo()
        }
        return nil
    }
    
    // Get user holdings for a specific index
    access(all) fun getUserHoldings(indexId: UInt64, user: Address): UserIndexHoldings? {
        if let index = self.indexes[indexId] {
            return index.getUserHoldings(user: user)
        }
        return nil
    }
    
    // Get all indexes
    access(all) fun getAllIndexes(): [IndexInfo] {
        let result: [IndexInfo] = []
        for index in self.indexes.values {
            result.append(index.getIndexInfo())
        }
        return result
    }
}

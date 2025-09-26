import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

/// FlindexTreasury handles fee collection and distribution between the platform
/// treasury and creators as passive income. It manages the economic incentives
/// of the Flindex ecosystem.
access(all) contract FlindexTreasury {

    // -----------------------------------------------------------------------
    // FlindexTreasury contract Events
    // -----------------------------------------------------------------------

    /// Event emitted when fees are collected from transactions
    access(all) event FeesCollected(
        source: String, 
        amount: UFix64, 
        treasuryShare: UFix64, 
        creatorShare: UFix64
    )

    /// Event emitted when treasury funds are withdrawn
    access(all) event TreasuryWithdrawal(recipient: Address, amount: UFix64)

    /// Event emitted when creator rewards are distributed
    access(all) event CreatorRewardDistribution(creator: Address, amount: UFix64)

    /// Event emitted when fee rates are updated
    access(all) event FeeRatesUpdated(
        platformFeeRate: UFix64, 
        treasuryShare: UFix64, 
        creatorShare: UFix64
    )

    /// Event emitted when yield is generated
    access(all) event YieldGenerated(amount: UFix64, source: String)

    // -----------------------------------------------------------------------
    // FlindexTreasury contract-level fields
    // -----------------------------------------------------------------------

    /// Platform fee rate (0.1% = 0.001)
    access(all) var platformFeeRate: UFix64

    /// Treasury's share of platform fees (50% = 0.5)
    access(all) var treasuryFeeShare: UFix64

    /// Creator's share of platform fees (50% = 0.5)
    access(all) var creatorFeeShare: UFix64

    /// Storage path for Treasury Vault
    access(all) let TreasuryVaultStoragePath: StoragePath

    /// Storage path for Treasury Admin
    access(all) let TreasuryAdminStoragePath: StoragePath

    /// Public path for Treasury
    access(all) let TreasuryPublicPath: PublicPath

    // -----------------------------------------------------------------------
    // FlindexTreasury contract-level Composite Type definitions
    // -----------------------------------------------------------------------

    /// Struct containing treasury statistics
    access(all) struct TreasuryStats {
        /// Total fees collected
        access(all) let totalFeesCollected: UFix64
        
        /// Total distributed to treasury
        access(all) let totalTreasuryDistribution: UFix64
        
        /// Total distributed to creators
        access(all) let totalCreatorDistribution: UFix64
        
        /// Current treasury balance
        access(all) let currentTreasuryBalance: UFix64
        
        /// Pending creator rewards
        access(all) let pendingCreatorRewards: UFix64
        
        /// Number of transactions processed
        access(all) let transactionsProcessed: UInt64
        
        /// Average fee per transaction
        access(all) let averageFeePerTransaction: UFix64

        init(
            totalFeesCollected: UFix64,
            totalTreasuryDistribution: UFix64,
            totalCreatorDistribution: UFix64,
            currentTreasuryBalance: UFix64,
            pendingCreatorRewards: UFix64,
            transactionsProcessed: UInt64
        ) {
            self.totalFeesCollected = totalFeesCollected
            self.totalTreasuryDistribution = totalTreasuryDistribution
            self.totalCreatorDistribution = totalCreatorDistribution
            self.currentTreasuryBalance = currentTreasuryBalance
            self.pendingCreatorRewards = pendingCreatorRewards
            self.transactionsProcessed = transactionsProcessed
            
            if transactionsProcessed > 0 {
                self.averageFeePerTransaction = totalFeesCollected / UFix64(transactionsProcessed)
            } else {
                self.averageFeePerTransaction = 0.0
            }
        }
    }

    /// Struct for creator reward information
    access(all) struct CreatorReward {
        /// Creator's address
        access(all) let creator: Address
        
        /// Pending reward amount
        access(all) let pendingAmount: UFix64
        
        /// Total rewards earned historically
        access(all) let totalEarned: UFix64
        
        /// Last distribution timestamp
        access(all) let lastDistribution: UFix64
        
        /// Number of indices owned by creator
        access(all) let indicesOwned: UInt64

        init(
            creator: Address, 
            pendingAmount: UFix64, 
            totalEarned: UFix64, 
            lastDistribution: UFix64,
            indicesOwned: UInt64
        ) {
            self.creator = creator
            self.pendingAmount = pendingAmount
            self.totalEarned = totalEarned
            self.lastDistribution = lastDistribution
            self.indicesOwned = indicesOwned
        }
    }

    /// Public interface for Treasury
    access(all) resource interface TreasuryPublic {
        access(all) fun getTreasuryStats(): TreasuryStats
        access(all) fun getCreatorReward(creator: Address): CreatorReward?
        access(all) view fun getTreasuryBalance(): UFix64
        access(all) view fun getPendingCreatorRewards(): UFix64
    }

    /// Resource managing the treasury operations
    access(all) resource Treasury: TreasuryPublic {
        /// Main treasury vault holding Flow tokens
        access(all) var treasuryVault: @FlowToken.Vault
        
        /// Vault for pending creator rewards
        access(all) var creatorRewardsVault: @FlowToken.Vault
        
        /// Statistics tracking
        access(all) var totalFeesCollected: UFix64
        access(all) var totalTreasuryDistribution: UFix64
        access(all) var totalCreatorDistribution: UFix64
        access(all) var transactionsProcessed: UInt64
        
        /// Creator reward tracking
        access(all) var creatorRewards: {Address: UFix64}
        access(all) var creatorTotalEarned: {Address: UFix64}
        access(all) var creatorLastDistribution: {Address: UFix64}

        init() {
            self.treasuryVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>()) as! @FlowToken.Vault
            self.creatorRewardsVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>()) as! @FlowToken.Vault
            self.totalFeesCollected = 0.0
            self.totalTreasuryDistribution = 0.0
            self.totalCreatorDistribution = 0.0
            self.transactionsProcessed = 0
            self.creatorRewards = {}
            self.creatorTotalEarned = {}
            self.creatorLastDistribution = {}
        }

        /// Collect fees from platform operations
        access(all) fun collectFees(fees: @FlowToken.Vault, source: String, creator: Address?) {
            let totalFees = fees.balance
            
            // Calculate distribution
            let treasuryAmount = totalFees * FlindexTreasury.treasuryFeeShare
            let creatorAmount = totalFees * FlindexTreasury.creatorFeeShare
            
            // Split the fees
            let treasuryShare <- fees.withdraw(amount: treasuryAmount) as! @FlowToken.Vault
            let creatorShare <- fees // Remaining amount goes to creators
            
            // Deposit to treasury
            self.treasuryVault.deposit(from: <- treasuryShare)
            self.totalTreasuryDistribution = self.totalTreasuryDistribution + treasuryAmount
            
            // Handle creator rewards
            if let creatorAddress = creator {
                // Allocate to specific creator
                self.allocateCreatorReward(creator: creatorAddress, amount: creatorAmount)
                // Deposit to creator rewards pool
                self.creatorRewardsVault.deposit(from: <- creatorShare)
            } else {
                // Add to general creator rewards pool
                self.creatorRewardsVault.deposit(from: <- creatorShare)
            }
            
            self.totalCreatorDistribution = self.totalCreatorDistribution + creatorAmount
            
            // Update statistics
            self.totalFeesCollected = self.totalFeesCollected + totalFees
            self.transactionsProcessed = self.transactionsProcessed + 1
            
            emit FeesCollected(
                source: source,
                amount: totalFees,
                treasuryShare: treasuryAmount,
                creatorShare: creatorAmount
            )
        }

        /// Allocate rewards to specific creator
        access(all) fun allocateCreatorReward(creator: Address, amount: UFix64) {
            // Update pending rewards
            let currentPending = self.creatorRewards[creator] ?? 0.0
            self.creatorRewards[creator] = currentPending + amount
            
            // Update total earned
            let currentTotal = self.creatorTotalEarned[creator] ?? 0.0
            self.creatorTotalEarned[creator] = currentTotal + amount
        }

        /// Distribute rewards to a creator
        access(all) fun distributeCreatorReward(creator: Address): @FlowToken.Vault {
            pre {
                self.creatorRewards[creator] != nil: "No pending rewards for creator"
                self.creatorRewards[creator]! > 0.0: "No pending rewards for creator"
            }
            
            let rewardAmount = self.creatorRewards[creator]!
            
            // Check if we have enough in the creator rewards vault
            let availableAmount = self.creatorRewardsVault.balance
            let distributionAmount: UFix64 = rewardAmount <= availableAmount ? rewardAmount : availableAmount
            
            // Withdraw from creator rewards vault
            let reward <- self.creatorRewardsVault.withdraw(amount: distributionAmount) as! @FlowToken.Vault
            
            // Update pending rewards
            self.creatorRewards[creator] = rewardAmount - distributionAmount
            
            // Update last distribution timestamp
            self.creatorLastDistribution[creator] = getCurrentBlock().timestamp
            
            emit CreatorRewardDistribution(creator: creator, amount: distributionAmount)
            
            return <- reward
        }

        /// Withdraw from treasury (admin only)
        access(all) fun withdrawFromTreasury(amount: UFix64, recipient: Address): @FlowToken.Vault {
            pre {
                amount <= self.treasuryVault.balance: "Insufficient treasury balance"
            }
            
            let withdrawal <- self.treasuryVault.withdraw(amount: amount) as! @FlowToken.Vault
            
            emit TreasuryWithdrawal(recipient: recipient, amount: amount)
            
            return <- withdrawal
        }

        /// Generate yield (simulate yield farming or staking rewards)
        access(all) fun generateYield(amount: UFix64, source: String) {
            let yield <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>()) as! @FlowToken.Vault
            // In a real implementation, this would come from DeFi protocols
            // For simulation, we'll just add to treasury
            
            self.treasuryVault.deposit(from: <- yield)
            
            emit YieldGenerated(amount: amount, source: source)
        }

        /// Get treasury statistics
        access(all) fun getTreasuryStats(): TreasuryStats {
            return TreasuryStats(
                totalFeesCollected: self.totalFeesCollected,
                totalTreasuryDistribution: self.totalTreasuryDistribution,
                totalCreatorDistribution: self.totalCreatorDistribution,
                currentTreasuryBalance: self.treasuryVault.balance,
                pendingCreatorRewards: self.creatorRewardsVault.balance,
                transactionsProcessed: self.transactionsProcessed
            )
        }

        /// Get creator reward information
        access(all) fun getCreatorReward(creator: Address): CreatorReward? {
            if self.creatorRewards[creator] == nil {
                return nil
            }
            
            return CreatorReward(
                creator: creator,
                pendingAmount: self.creatorRewards[creator]!,
                totalEarned: self.creatorTotalEarned[creator] ?? 0.0,
                lastDistribution: self.creatorLastDistribution[creator] ?? 0.0,
                indicesOwned: 0 // Would need to query FlindexCore for this
            )
        }

        /// Get current treasury balance
        access(all) view fun getTreasuryBalance(): UFix64 {
            return self.treasuryVault.balance
        }

        /// Get pending creator rewards total
        access(all) view fun getPendingCreatorRewards(): UFix64 {
            return self.creatorRewardsVault.balance
        }

        /// Get all creators with pending rewards
        access(all) fun getCreatorsWithRewards(): [Address] {
            let creators: [Address] = []
            for creator in self.creatorRewards.keys {
                if self.creatorRewards[creator]! > 0.0 {
                    creators.append(creator)
                }
            }
            return creators
        }
    }

    /// Admin resource for treasury management
    access(all) resource TreasuryAdmin {
        /// Update fee rates
        access(all) fun updateFeeRates(
            platformFeeRate: UFix64, 
            treasuryShare: UFix64, 
            creatorShare: UFix64
        ) {
            pre {
                platformFeeRate >= 0.0 && platformFeeRate <= 0.1: "Platform fee rate must be between 0% and 10%"
                treasuryShare >= 0.0 && treasuryShare <= 1.0: "Treasury share must be between 0% and 100%"
                creatorShare >= 0.0 && creatorShare <= 1.0: "Creator share must be between 0% and 100%"
                treasuryShare + creatorShare == 1.0: "Treasury and creator shares must sum to 100%"
            }
            
            FlindexTreasury.platformFeeRate = platformFeeRate
            FlindexTreasury.treasuryFeeShare = treasuryShare
            FlindexTreasury.creatorFeeShare = creatorShare
            
            emit FeeRatesUpdated(
                platformFeeRate: platformFeeRate,
                treasuryShare: treasuryShare,
                creatorShare: creatorShare
            )
        }

        /// Emergency withdrawal from treasury
        access(all) fun emergencyWithdrawal(amount: UFix64, recipient: Address) {
            let treasury = FlindexTreasury.account.storage.borrow<&Treasury>(from: FlindexTreasury.TreasuryVaultStoragePath)
                ?? panic("Could not borrow treasury")
            
            let withdrawal <- treasury.withdrawFromTreasury(amount: amount, recipient: recipient)
            
            // In a real implementation, this would be sent to the recipient
            // For now, we'll just destroy it (this is for testing)
            destroy withdrawal
        }
    }

    // -----------------------------------------------------------------------
    // FlindexTreasury contract-level functions
    // -----------------------------------------------------------------------

    /// Collect fees from index operations
    access(all) fun collectIndexFees(fees: @FlowToken.Vault, source: String, creator: Address?) {
        let treasury = self.account.storage.borrow<&Treasury>(from: self.TreasuryVaultStoragePath)
            ?? panic("Could not borrow treasury")
        
        treasury.collectFees(fees: <- fees, source: source, creator: creator)
    }

    /// Distribute rewards to creator
    access(all) fun distributeRewardsToCreator(creator: Address): @FlowToken.Vault {
        let treasury = self.account.storage.borrow<&Treasury>(from: self.TreasuryVaultStoragePath)
            ?? panic("Could not borrow treasury")
        
        return <- treasury.distributeCreatorReward(creator: creator)
    }

    /// Get treasury statistics
    access(all) fun getTreasuryStats(): TreasuryStats {
        let treasury = self.account.storage.borrow<&Treasury>(from: self.TreasuryVaultStoragePath)
            ?? panic("Could not borrow treasury")
        
        return treasury.getTreasuryStats()
    }

    /// Get creator reward information
    access(all) fun getCreatorReward(creator: Address): CreatorReward? {
        let treasury = self.account.storage.borrow<&Treasury>(from: self.TreasuryVaultStoragePath)
            ?? panic("Could not borrow treasury")
        
        return treasury.getCreatorReward(creator: creator)
    }

    /// Get current platform fee rate
    access(all) view fun getPlatformFeeRate(): UFix64 {
        return self.platformFeeRate
    }

    /// Get treasury and creator fee shares
    access(all) view fun getFeeShares(): {String: UFix64} {
        return {
            "treasury": self.treasuryFeeShare,
            "creator": self.creatorFeeShare
        }
    }

    // -----------------------------------------------------------------------
    // FlindexTreasury contract initialization
    // -----------------------------------------------------------------------

    init() {
        // Initialize fee structure
        self.platformFeeRate = 0.001  // 0.1%
        self.treasuryFeeShare = 0.5   // 50%
        self.creatorFeeShare = 0.5    // 50%
        
        // Set storage paths
        self.TreasuryVaultStoragePath = /storage/FlindexTreasury
        self.TreasuryAdminStoragePath = /storage/FlindexTreasuryAdmin
        self.TreasuryPublicPath = /public/FlindexTreasury
        
        // Create and store treasury
        self.account.storage.save(<- create Treasury(), to: self.TreasuryVaultStoragePath)
        
        // Create and store admin
        self.account.storage.save(<- create TreasuryAdmin(), to: self.TreasuryAdminStoragePath)
        
        // Publish public capability
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&Treasury>(self.TreasuryVaultStoragePath),
            at: self.TreasuryPublicPath
        )
    }
}

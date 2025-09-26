import FungibleToken from 0xee82856bf20e2aa6
import FlindexCore from 0xf8d6e0586b0a20c7
import ViewResolver from 0xf8d6e0586b0a20c7

/// FlindexCreator manages creator permissions, index creation, and rebalancing
/// upon project token payment. Creators must hold and pay project tokens to
/// create new indices and perform rebalancing operations.
access(all) contract FlindexCreator {

    // -----------------------------------------------------------------------
    // FlindexCreator contract Events
    // -----------------------------------------------------------------------

    /// Event emitted when a creator is registered
    access(all) event CreatorRegistered(creator: Address, projectTokensStaked: UFix64)

    /// Event emitted when project tokens are paid for index creation
    access(all) event ProjectTokensPaidForCreation(
        creator: Address, 
        indexId: UInt64, 
        tokensPaid: UFix64
    )

    /// Event emitted when project tokens are paid for rebalancing
    access(all) event ProjectTokensPaidForRebalancing(
        creator: Address, 
        indexId: UInt64, 
        tokensPaid: UFix64
    )

    /// Event emitted when creator rewards are distributed
    access(all) event CreatorRewardsDistributed(creator: Address, amount: UFix64)

    // -----------------------------------------------------------------------
    // FlindexCreator contract-level fields
    // -----------------------------------------------------------------------

    /// Cost in project tokens to create a new index
    access(all) let indexCreationCost: UFix64

    /// Cost in project tokens to rebalance an index
    access(all) let rebalancingCost: UFix64

    /// Minimum project tokens required to become a creator
    access(all) let minimumStakeRequired: UFix64

    /// Storage path for Creator resource
    access(all) let CreatorStoragePath: StoragePath

    /// Public path for Creator resource
    access(all) let CreatorPublicPath: PublicPath

    /// Storage path for Project Token Vault
    access(all) let ProjectTokenVaultStoragePath: StoragePath

    // -----------------------------------------------------------------------
    // FlindexCreator contract-level Composite Type definitions
    // -----------------------------------------------------------------------

    /// Resource representing project tokens used for payments
    access(all) resource ProjectToken: FungibleToken.Vault, ViewResolver.Resolver {
        /// Balance of project tokens
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        /// Withdraw project tokens
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                amount > 0.0: "Withdrawal amount must be positive"
                amount <= self.balance: "Insufficient balance"
            }
            
            self.balance = self.balance - amount
            return <- create ProjectToken(balance: amount)
        }

        /// Deposit project tokens
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @ProjectToken
            self.balance = self.balance + vault.balance
            destroy vault
        }

        /// Get balance
        access(all) view fun getBalance(): UFix64 {
            return self.balance
        }

        /// Check if withdrawal is possible
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        /// Get supported vault types
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {Type<@ProjectToken>(): true}
        }

        /// Create empty vault of same type
        access(all) fun createEmptyVault(): @{FungibleToken.Vault} {
            return <- create ProjectToken(balance: 0.0)
        }

        /// ViewResolver.Resolver implementation
        access(all) view fun getViews(): [Type] {
            return []
        }

        /// Resolve metadata view
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }
    }

    /// Struct containing creator information and statistics
    access(all) struct CreatorInfo {
        /// Creator's address
        access(all) let address: Address
        
        /// Amount of project tokens staked
        access(all) var stakedTokens: UFix64
        
        /// Total indices created by this creator
        access(all) var indicesCreated: UInt64
        
        /// Total rebalancing operations performed
        access(all) var rebalancingOperations: UInt64
        
        /// Total rewards earned
        access(all) var totalRewardsEarned: UFix64
        
        /// Registration timestamp
        access(all) let registeredAt: UFix64
        
        /// List of index IDs created by this creator
        access(all) var createdIndices: [UInt64]

        init(address: Address, stakedTokens: UFix64) {
            self.address = address
            self.stakedTokens = stakedTokens
            self.indicesCreated = 0
            self.rebalancingOperations = 0
            self.totalRewardsEarned = 0.0
            self.registeredAt = getCurrentBlock().timestamp
            self.createdIndices = []
        }

        /// Update staked tokens (only callable by contract)
        access(contract) fun updateStakedTokens(_ amount: UFix64) {
            self.stakedTokens = amount
        }

        /// Increment indices created (only callable by contract)
        access(contract) fun incrementIndicesCreated(_ indexId: UInt64) {
            self.indicesCreated = self.indicesCreated + 1
            self.createdIndices.append(indexId)
        }

        /// Increment rebalancing operations (only callable by contract)
        access(contract) fun incrementRebalancingOperations() {
            self.rebalancingOperations = self.rebalancingOperations + 1
        }

        /// Add rewards earned (only callable by contract)
        access(contract) fun addRewards(_ amount: UFix64) {
            self.totalRewardsEarned = self.totalRewardsEarned + amount
        }
    }

    /// Public interface for Creator resource
    access(all) resource interface CreatorPublic {
        access(all) view fun getCreatorInfo(): CreatorInfo
        access(all) view fun getStakedTokens(): UFix64
        access(all) view fun canCreateIndex(): Bool
        access(all) view fun canRebalanceIndex(): Bool
    }

    /// Resource representing a registered creator
    access(all) resource Creator: CreatorPublic {
        /// Creator information
        access(all) var info: CreatorInfo
        
        /// Project token vault for payments
        access(all) var projectTokenVault: @ProjectToken

        init(address: Address, initialStake: @ProjectToken) {
            pre {
                initialStake.balance >= FlindexCreator.minimumStakeRequired: 
                    "Initial stake must meet minimum requirement"
            }
            
            self.info = CreatorInfo(address: address, stakedTokens: initialStake.balance)
            self.projectTokenVault <- initialStake
        }

        /// Get creator information
        access(all) view fun getCreatorInfo(): CreatorInfo {
            return self.info
        }

        /// Get staked tokens
        access(all) view fun getStakedTokens(): UFix64 {
            return self.projectTokenVault.balance
        }

        /// Check if creator can create an index
        access(all) view fun canCreateIndex(): Bool {
            return self.projectTokenVault.balance >= FlindexCreator.indexCreationCost
        }

        /// Check if creator can rebalance an index
        access(all) view fun canRebalanceIndex(): Bool {
            return self.projectTokenVault.balance >= FlindexCreator.rebalancingCost
        }

        /// Stake additional project tokens
        access(all) fun stakeTokens(tokens: @ProjectToken) {
            let amount = tokens.balance
            self.projectTokenVault.deposit(from: <- tokens)
            self.info.updateStakedTokens(self.projectTokenVault.balance)
        }

        /// Create a new index (internal function called by contract)
        access(contract) fun createIndex(
            name: String, 
            description: String, 
            composition: {String: UFix64}
        ): UInt64 {
            pre {
                self.canCreateIndex(): "Insufficient project tokens for index creation"
            }
            
            // Pay creation cost
            let payment <- self.projectTokenVault.withdraw(amount: FlindexCreator.indexCreationCost) as! @ProjectToken
            FlindexCreator.collectProjectTokens(tokens: <- payment)
            
            // Create index through FlindexCore
            let indexId = FlindexCore.createIndex(
                name: name,
                description: description,
                creator: self.info.address,
                composition: composition
            )
            
            // Update creator stats
            self.info.incrementIndicesCreated(indexId)
            
            emit ProjectTokensPaidForCreation(
                creator: self.info.address,
                indexId: indexId,
                tokensPaid: FlindexCreator.indexCreationCost
            )
            
            return indexId
        }

        /// Rebalance an existing index (internal function called by contract)
        access(contract) fun rebalanceIndex(indexId: UInt64, newComposition: {String: UFix64}) {
            pre {
                self.canRebalanceIndex(): "Insufficient project tokens for rebalancing"
            }
            
            // Verify creator owns the index
            let metadata = FlindexCore.getIndexMetadata(indexId: indexId)
            assert(
                metadata.creator == self.info.address, 
                message: "Creator does not own this index"
            )
            
            // Pay rebalancing cost
            let payment <- self.projectTokenVault.withdraw(amount: FlindexCreator.rebalancingCost) as! @ProjectToken
            FlindexCreator.collectProjectTokens(tokens: <- payment)
            
            // Perform rebalancing through FlindexCore
            FlindexCore.rebalanceIndex(
                indexId: indexId,
                creator: self.info.address,
                newComposition: newComposition
            )
            
            // Update creator stats
            self.info.incrementRebalancingOperations()
            
            emit ProjectTokensPaidForRebalancing(
                creator: self.info.address,
                indexId: indexId,
                tokensPaid: FlindexCreator.rebalancingCost
            )
        }

        /// Receive rewards from platform fees
        access(contract) fun receiveRewards(amount: UFix64) {
            // In a full implementation, this would deposit Flow tokens
            // For now, we just track the rewards
            self.info.addRewards(amount)
            
            emit CreatorRewardsDistributed(creator: self.info.address, amount: amount)
        }
    }

    // -----------------------------------------------------------------------
    // FlindexCreator contract-level fields
    // -----------------------------------------------------------------------

    /// Dictionary storing all registered creators
    access(contract) var creators: {Address: CreatorInfo}

    /// Total project tokens collected
    access(contract) var totalProjectTokensCollected: UFix64

    /// Project token supply for distribution
    access(contract) var projectTokenSupply: UFix64

    // -----------------------------------------------------------------------
    // FlindexCreator contract-level functions
    // -----------------------------------------------------------------------

    /// Register as a creator by staking project tokens
    access(all) fun registerCreator(creator: Address, initialStake: @ProjectToken): @Creator {
        pre {
            self.creators[creator] == nil: "Creator already registered"
            initialStake.balance >= self.minimumStakeRequired: 
                "Initial stake must meet minimum requirement"
        }
        
        let creatorResource <- create Creator(address: creator, initialStake: <- initialStake)
        let creatorInfo = creatorResource.getCreatorInfo()
        
        self.creators[creator] = creatorInfo
        
        emit CreatorRegistered(creator: creator, projectTokensStaked: creatorInfo.stakedTokens)
        
        return <- creatorResource
    }

    /// Create an index through a creator
    access(all) fun createIndexAsCreator(
        creatorRef: &Creator, 
        name: String, 
        description: String, 
        composition: {String: UFix64}
    ): UInt64 {
        pre {
            self.creators[creatorRef.info.address] != nil: "Creator not registered"
        }
        
        let indexId = creatorRef.createIndex(
            name: name,
            description: description,
            composition: composition
        )
        
        // Update stored creator info
        self.creators[creatorRef.info.address] = creatorRef.getCreatorInfo()
        
        return indexId
    }

    /// Rebalance an index through a creator
    access(all) fun rebalanceIndexAsCreator(
        creatorRef: &Creator, 
        indexId: UInt64, 
        newComposition: {String: UFix64}
    ) {
        pre {
            self.creators[creatorRef.info.address] != nil: "Creator not registered"
        }
        
        creatorRef.rebalanceIndex(indexId: indexId, newComposition: newComposition)
        
        // Update stored creator info
        self.creators[creatorRef.info.address] = creatorRef.getCreatorInfo()
    }

    /// Get creator information
    access(all) view fun getCreatorInfo(creator: Address): CreatorInfo? {
        return self.creators[creator]
    }

    /// Check if address is a registered creator
    access(all) view fun isRegisteredCreator(creator: Address): Bool {
        return self.creators[creator] != nil
    }

    /// Get all registered creator addresses
    access(all) view fun getAllCreators(): [Address] {
        return self.creators.keys
    }

    /// Mint project tokens (admin function for testing)
    access(all) fun mintProjectTokens(amount: UFix64): @ProjectToken {
        self.projectTokenSupply = self.projectTokenSupply + amount
        return <- create ProjectToken(balance: amount)
    }

    /// Collect project tokens from payments
    access(contract) fun collectProjectTokens(tokens: @ProjectToken) {
        self.totalProjectTokensCollected = self.totalProjectTokensCollected + tokens.balance
        destroy tokens
    }

    /// Distribute rewards to creators (admin function)
    access(all) fun distributeRewards(creator: Address, amount: UFix64) {
        pre {
            self.creators[creator] != nil: "Creator not found"
        }
        
        // In a full implementation, this would involve actual Flow token transfers
        // For now, we just emit the event and update tracking
        emit CreatorRewardsDistributed(creator: creator, amount: amount)
    }

    /// Get total project tokens collected
    access(all) view fun getTotalProjectTokensCollected(): UFix64 {
        return self.totalProjectTokensCollected
    }

    /// Get project token supply
    access(all) view fun getProjectTokenSupply(): UFix64 {
        return self.projectTokenSupply
    }

    // -----------------------------------------------------------------------
    // FlindexCreator contract initialization
    // -----------------------------------------------------------------------

    init() {
        // Initialize contract fields
        self.indexCreationCost = 100.0      // 100 project tokens
        self.rebalancingCost = 50.0         // 50 project tokens
        self.minimumStakeRequired = 500.0   // 500 project tokens minimum stake
        
        // Set storage paths
        self.CreatorStoragePath = /storage/FlindexCreator
        self.CreatorPublicPath = /public/FlindexCreator
        self.ProjectTokenVaultStoragePath = /storage/FlindexProjectTokenVault
        
        // Initialize storage
        self.creators = {}
        self.totalProjectTokensCollected = 0.0
        self.projectTokenSupply = 1000000.0 // Initial supply of 1M tokens
    }
}

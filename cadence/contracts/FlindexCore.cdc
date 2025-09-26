import FungibleToken from 0xee82856bf20e2aa6
import MetadataViews from 0xf8d6e0586b0a20c7
import FungibleTokenMetadataViews from 0xee82856bf20e2aa6
import ViewResolver from 0xf8d6e0586b0a20c7

/// FlindexCore is the main contract for managing decentralized crypto index funds
/// on the Flow blockchain. It handles index token minting, burning, valuation,
/// and user buy/sell transactions with real-time pricing via Pyth oracles.
access(all) contract FlindexCore {

    // -----------------------------------------------------------------------
    // FlindexCore contract Events
    // -----------------------------------------------------------------------

    /// Event emitted when a new index is created
    access(all) event IndexCreated(
        indexId: UInt64, 
        creator: Address, 
        name: String, 
        composition: {String: UFix64}
    )

    /// Event emitted when an index is rebalanced
    access(all) event IndexRebalanced(
        indexId: UInt64, 
        creator: Address, 
        newComposition: {String: UFix64}
    )

    /// Event emitted when index tokens are purchased
    access(all) event IndexTokensPurchased(
        buyer: Address, 
        indexId: UInt64, 
        flowAmount: UFix64, 
        tokensReceived: UFix64, 
        fee: UFix64
    )

    /// Event emitted when index tokens are sold
    access(all) event IndexTokensSold(
        seller: Address, 
        indexId: UInt64, 
        tokensSold: UFix64, 
        flowReceived: UFix64, 
        fee: UFix64
    )

    /// Event emitted when index valuation is updated
    access(all) event IndexValuationUpdated(
        indexId: UInt64, 
        totalValue: UFix64, 
        pricePerToken: UFix64
    )

    // -----------------------------------------------------------------------
    // FlindexCore contract-level fields
    // -----------------------------------------------------------------------

    /// The next available index ID
    access(all) var nextIndexId: UInt64

    /// Platform fee percentage (0.1% = 0.001)
    access(all) let platformFeeRate: UFix64

    /// Treasury share of platform fees (50% = 0.5)
    access(all) let treasuryFeeShare: UFix64

    /// Creator share of platform fees (50% = 0.5)  
    access(all) let creatorFeeShare: UFix64

    /// Storage path for IndexToken Collection
    access(all) let CollectionStoragePath: StoragePath

    /// Public path for IndexToken Collection
    access(all) let CollectionPublicPath: PublicPath

    /// Storage path for IndexToken Minter
    access(all) let MinterStoragePath: StoragePath

    // -----------------------------------------------------------------------
    // FlindexCore contract-level Composite Type definitions
    // -----------------------------------------------------------------------

    /// Struct representing the composition of an index
    access(all) struct IndexComposition {
        /// Asset symbol to percentage mapping (percentages sum to 1.0)
        access(all) let assets: {String: UFix64}
        
        /// Timestamp when this composition was set
        access(all) let timestamp: UFix64

        init(assets: {String: UFix64}) {
            pre {
                assets.keys.length > 0: "Index must contain at least one asset"
            }
            
            // Verify percentages sum to 1.0 (100%)
            var total: UFix64 = 0.0
            for percentage in assets.values {
                total = total + percentage
            }
            
            assert(
                total >= 0.99 && total <= 1.01, 
                message: "Asset percentages must sum to 100% (1.0)"
            )
            
            self.assets = assets
            self.timestamp = getCurrentBlock().timestamp
        }
    }

    /// Struct containing metadata about an index
    access(all) struct IndexMetadata {
        /// Unique identifier for the index
        access(all) let indexId: UInt64
        
        /// Human-readable name of the index
        access(all) let name: String
        
        /// Description of the index strategy
        access(all) let description: String
        
        /// Address of the index creator
        access(all) let creator: Address
        
        /// Current asset composition
        access(all) var composition: IndexComposition
        
        /// Total supply of index tokens
        access(all) var totalSupply: UFix64
        
        /// Current total value of the index in Flow tokens
        access(all) var totalValue: UFix64
        
        /// Creation timestamp
        access(all) let createdAt: UFix64
        
        /// History of rebalancing events
        access(all) var rebalanceHistory: [IndexComposition]

        init(
            indexId: UInt64, 
            name: String, 
            description: String, 
            creator: Address, 
            composition: IndexComposition
        ) {
            self.indexId = indexId
            self.name = name
            self.description = description
            self.creator = creator
            self.composition = composition
            self.totalSupply = 0.0
            self.totalValue = 0.0
            self.createdAt = getCurrentBlock().timestamp
            self.rebalanceHistory = []
        }

        /// Update the index composition (only callable by contract)
        access(contract) fun updateComposition(_ newComposition: IndexComposition) {
            self.rebalanceHistory.append(self.composition)
            self.composition = newComposition
        }

        /// Update total supply (only callable by contract)
        access(contract) fun updateTotalSupply(_ newSupply: UFix64) {
            self.totalSupply = newSupply
        }

        /// Update total value (only callable by contract)
        access(contract) fun updateTotalValue(_ newValue: UFix64) {
            self.totalValue = newValue
        }

        /// Get current price per token
        access(all) view fun getPricePerToken(): UFix64 {
            if self.totalSupply == 0.0 {
                return 1.0 // Initial price
            }
            return self.totalValue / self.totalSupply
        }
    }

    /// Resource representing ownership in a crypto index
    access(all) resource IndexToken: FungibleToken.Vault, ViewResolver.Resolver {
        /// The index this token represents
        access(all) let indexId: UInt64
        
        /// Amount of tokens held
        access(all) var balance: UFix64

        init(indexId: UInt64, balance: UFix64) {
            self.indexId = indexId
            self.balance = balance
        }

        /// Withdraw tokens from this vault
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                amount > 0.0: "Withdrawal amount must be positive"
                amount <= self.balance: "Insufficient balance"
            }
            
            self.balance = self.balance - amount
            return <- create IndexToken(indexId: self.indexId, balance: amount)
        }

        /// Deposit tokens into this vault
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @IndexToken
            assert(
                vault.indexId == self.indexId,
                message: "Cannot deposit tokens from different index"
            )
            
            self.balance = self.balance + vault.balance
            destroy vault
        }

        /// Get the balance of this vault
        access(all) view fun getBalance(): UFix64 {
            return self.balance
        }

        /// Check if the vault is supported
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        /// Get supported vault types
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {Type<@IndexToken>(): true}
        }

        /// Create empty vault of same type
        access(all) fun createEmptyVault(): @{FungibleToken.Vault} {
            return <- create IndexToken(indexId: self.indexId, balance: 0.0)
        }

        /// ViewResolver.Resolver implementation
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<FungibleTokenMetadataViews.FTDisplay>()
            ]
        }

        /// Resolve metadata view
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let metadata = FlindexCore.getIndexMetadata(indexId: self.indexId)
                    return MetadataViews.Display(
                        name: metadata.name,
                        description: metadata.description,
                        thumbnail: MetadataViews.HTTPFile(url: "https://flindex.io/icons/".concat(self.indexId.toString()).concat(".png"))
                    )
                
                case Type<FungibleTokenMetadataViews.FTDisplay>():
                    let metadata = FlindexCore.getIndexMetadata(indexId: self.indexId)
                    return FungibleTokenMetadataViews.FTDisplay(
                        name: metadata.name,
                        symbol: "FLX".concat(self.indexId.toString()),
                        description: metadata.description,
                        externalURL: MetadataViews.ExternalURL("https://flindex.io/index/".concat(self.indexId.toString())),
                        logos: MetadataViews.Medias([
                            MetadataViews.Media(
                                file: MetadataViews.HTTPFile(url: "https://flindex.io/logos/".concat(self.indexId.toString()).concat(".png")),
                                mediaType: "image/png"
                            )
                        ]),
                        socials: {}
                    )
            }
            return nil
        }
    }

    /// Collection interface for managing multiple IndexTokens
    access(all) resource interface CollectionPublic {
        access(all) view fun getBalance(indexId: UInt64): UFix64
        access(all) view fun getIndexIds(): [UInt64]
        access(all) fun deposit(token: @IndexToken)
    }

    /// Collection for holding multiple IndexToken vaults
    access(all) resource Collection: CollectionPublic {
        /// Dictionary of IndexToken vaults
        access(all) var vaults: @{UInt64: IndexToken}

        init() {
            self.vaults <- {}
        }

        /// Get balance for specific index
        access(all) view fun getBalance(indexId: UInt64): UFix64 {
            if let vault = &self.vaults[indexId] as &IndexToken? {
                return vault.getBalance()
            }
            return 0.0
        }

        /// Get all index IDs held in this collection
        access(all) view fun getIndexIds(): [UInt64] {
            return self.vaults.keys
        }

        /// Deposit IndexToken into collection
        access(all) fun deposit(token: @IndexToken) {
            let indexId = token.indexId
            
            if let existingVault = &self.vaults[indexId] as &IndexToken? {
                existingVault.deposit(from: <- token)
            } else {
                self.vaults[indexId] <-! token
            }
        }

        /// Withdraw IndexToken from collection
        access(all) fun withdraw(indexId: UInt64, amount: UFix64): @IndexToken {
            pre {
                self.vaults[indexId] != nil: "No vault found for index"
            }
            
            let vault = &self.vaults[indexId] as auth(FungibleToken.Withdraw) &IndexToken?
                ?? panic("No vault found for index")
            
            return <- vault.withdraw(amount: amount) as! @IndexToken
        }
    }

    /// Minter resource for creating new IndexTokens
    access(all) resource Minter {
        /// Mint new IndexTokens for an index
        access(all) fun mintTokens(indexId: UInt64, amount: UFix64): @IndexToken {
            pre {
                amount > 0.0: "Mint amount must be positive"
                FlindexCore.indices[indexId] != nil: "Index does not exist"
            }
            
            // Update total supply in metadata
            let metadata = FlindexCore.indices[indexId]!
            metadata.updateTotalSupply(metadata.totalSupply + amount)
            FlindexCore.indices[indexId] = metadata
            
            return <- create IndexToken(indexId: indexId, balance: amount)
        }

        /// Burn IndexTokens
        access(all) fun burnTokens(tokens: @IndexToken) {
            let indexId = tokens.indexId
            let amount = tokens.balance
            
            // Update total supply in metadata
            let metadata = FlindexCore.indices[indexId]!
            metadata.updateTotalSupply(metadata.totalSupply - amount)
            FlindexCore.indices[indexId] = metadata
            
            destroy tokens
        }
    }

    // -----------------------------------------------------------------------
    // FlindexCore contract-level fields
    // -----------------------------------------------------------------------

    /// Dictionary storing all index metadata
    access(contract) var indices: {UInt64: IndexMetadata}

    /// Mock Pyth oracle prices (in production, this would connect to actual Pyth)
    access(contract) var mockPrices: {String: UFix64}

    // -----------------------------------------------------------------------
    // FlindexCore contract-level functions
    // -----------------------------------------------------------------------

    /// Create a new crypto index
    access(all) fun createIndex(
        name: String, 
        description: String, 
        creator: Address, 
        composition: {String: UFix64}
    ): UInt64 {
        pre {
            name.length > 0: "Index name cannot be empty"
            description.length > 0: "Index description cannot be empty"
            composition.keys.length > 0: "Index must contain at least one asset"
        }
        
        let indexComposition = IndexComposition(assets: composition)
        let metadata = IndexMetadata(
            indexId: self.nextIndexId,
            name: name,
            description: description,
            creator: creator,
            composition: indexComposition
        )
        
        self.indices[self.nextIndexId] = metadata
        
        emit IndexCreated(
            indexId: self.nextIndexId,
            creator: creator,
            name: name,
            composition: composition
        )
        
        let currentId = self.nextIndexId
        self.nextIndexId = self.nextIndexId + 1
        
        return currentId
    }

    /// Rebalance an existing index (only creator can call)
    access(all) fun rebalanceIndex(indexId: UInt64, creator: Address, newComposition: {String: UFix64}) {
        pre {
            self.indices[indexId] != nil: "Index does not exist"
        }
        
        let metadata = self.indices[indexId]!
        assert(
            metadata.creator == creator,
            message: "Only index creator can rebalance"
        )
        
        let newIndexComposition = IndexComposition(assets: newComposition)
        metadata.updateComposition(newIndexComposition)
        self.indices[indexId] = metadata
        
        emit IndexRebalanced(
            indexId: indexId,
            creator: creator,
            newComposition: newComposition
        )
    }

    /// Get current index valuation using mock Pyth prices
    access(all) view fun getIndexValuation(indexId: UInt64): UFix64 {
        pre {
            self.indices[indexId] != nil: "Index does not exist"
        }
        
        let metadata = self.indices[indexId]!
        var totalValue: UFix64 = 0.0
        
        for asset in metadata.composition.assets.keys {
            let percentage = metadata.composition.assets[asset]!
            let price = self.mockPrices[asset] ?? 1.0
            totalValue = totalValue + (percentage * price)
        }
        
        return totalValue
    }

    /// Buy index tokens with Flow
    access(all) fun buyIndex(buyer: Address, indexId: UInt64, flowAmount: UFix64): @IndexToken {
        pre {
            flowAmount > 0.0: "Purchase amount must be positive"
            self.indices[indexId] != nil: "Index does not exist"
        }
        
        let metadata = self.indices[indexId]!
        let indexValue = self.getIndexValuation(indexId: indexId)
        let pricePerToken = metadata.getPricePerToken()
        
        // Calculate fees
        let fee = flowAmount * self.platformFeeRate
        let netAmount = flowAmount - fee
        
        // Calculate tokens to mint
        let tokensToMint = netAmount / pricePerToken
        
        // Update metadata
        metadata.updateTotalValue(metadata.totalValue + netAmount)
        self.indices[indexId] = metadata
        
        // Mint tokens
        let minter = self.account.storage.borrow<&Minter>(from: self.MinterStoragePath)
            ?? panic("Could not borrow minter")
        
        let tokens <- minter.mintTokens(indexId: indexId, amount: tokensToMint)
        
        emit IndexTokensPurchased(
            buyer: buyer,
            indexId: indexId,
            flowAmount: flowAmount,
            tokensReceived: tokensToMint,
            fee: fee
        )
        
        return <- tokens
    }

    /// Sell index tokens for Flow
    access(all) fun sellIndex(seller: Address, tokens: @IndexToken): UFix64 {
        pre {
            tokens.balance > 0.0: "Cannot sell zero tokens"
        }
        
        let indexId = tokens.indexId
        let tokenAmount = tokens.balance
        
        let metadata = self.indices[indexId]!
        let pricePerToken = metadata.getPricePerToken()
        
        // Calculate Flow to return
        let grossFlow = tokenAmount * pricePerToken
        let fee = grossFlow * self.platformFeeRate
        let netFlow = grossFlow - fee
        
        // Update metadata
        metadata.updateTotalValue(metadata.totalValue - grossFlow)
        self.indices[indexId] = metadata
        
        // Burn tokens
        let minter = self.account.storage.borrow<&Minter>(from: self.MinterStoragePath)
            ?? panic("Could not borrow minter")
        
        minter.burnTokens(tokens: <- tokens)
        
        emit IndexTokensSold(
            seller: seller,
            indexId: indexId,
            tokensSold: tokenAmount,
            flowReceived: netFlow,
            fee: fee
        )
        
        return netFlow
    }

    /// Get index metadata
    access(all) view fun getIndexMetadata(indexId: UInt64): IndexMetadata {
        pre {
            self.indices[indexId] != nil: "Index does not exist"
        }
        
        return self.indices[indexId]!
    }

    /// Update mock price (for testing - in production this would be Pyth oracle)
    access(all) fun updateMockPrice(asset: String, price: UFix64) {
        self.mockPrices[asset] = price
    }

    /// Get mock price
    access(all) view fun getMockPrice(asset: String): UFix64 {
        return self.mockPrices[asset] ?? 1.0
    }

    /// Create empty collection
    access(all) fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    // -----------------------------------------------------------------------
    // FlindexCore contract initialization
    // -----------------------------------------------------------------------

    init() {
        // Initialize contract fields
        self.nextIndexId = 1
        self.platformFeeRate = 0.001 // 0.1%
        self.treasuryFeeShare = 0.5  // 50%
        self.creatorFeeShare = 0.5   // 50%
        
        // Set storage paths
        self.CollectionStoragePath = /storage/FlindexTokenCollection
        self.CollectionPublicPath = /public/FlindexTokenCollection
        self.MinterStoragePath = /storage/FlindexMinter
        
        // Initialize storage
        self.indices = {}
        self.mockPrices = {
            "BTC": 45000.0,
            "ETH": 3000.0,
            "FLOW": 1.0,
            "USDC": 1.0,
            "SOL": 100.0,
            "ADA": 0.5,
            "DOT": 7.0,
            "LINK": 15.0,
            "UNI": 6.0,
            "AVAX": 25.0
        }
        
        // Create and store minter
        self.account.storage.save(<- create Minter(), to: self.MinterStoragePath)
        
        // Create and store admin collection
        self.account.storage.save(<- create Collection(), to: self.CollectionStoragePath)
        
        // Publish public capability
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&Collection>(self.CollectionStoragePath),
            at: self.CollectionPublicPath
        )
    }
}

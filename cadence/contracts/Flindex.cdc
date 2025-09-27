import "FungibleToken"
import "FlowToken"
import "DeFiActions"

/// Flindex is a decentralized on-chain crypto index fund composed of TRUMP and USDF tokens.
/// Investors contribute Flow and receive shares that represent proportional ownership in the
/// underlying vaults. Flow contributions are split evenly between TRUMP and USDF during buys,
/// and redemptions exit proportionally from both assets.
pub contract Flindex {

    pub type IndexID = UInt64

    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath
    pub let FlowVaultType: Type
    pub let UserPositionsStoragePath: StoragePath
    pub let UserPositionsPublicPath: PublicPath
    pub let holdingsEpsilon: UFix64

    access(self) var nextIndexID: IndexID
    access(self) var indices: @{IndexID: @Index}

    pub event IndexCreated(id: IndexID, creator: Address)
    pub event IndexBought(id: IndexID, user: Address, flowIn: UFix64, sharesOut: UFix64)
    pub event IndexSold(id: IndexID, user: Address, sharesIn: UFix64, flowOut: UFix64)

    pub struct IndexMetadata {
        pub let name: String
        pub let description: String
        pub let managementFeeBps: UInt64
        pub let createdAt: UFix64

        init(name: String, description: String, managementFeeBps: UInt64, createdAt: UFix64) {
            self.name = name
            self.description = description
            self.managementFeeBps = managementFeeBps
            self.createdAt = createdAt
        }
    }

    pub resource interface IndexPublic {
        pub fun getID(): IndexID
        pub fun getCreator(): Address
        pub fun getMetadata(): IndexMetadata
        pub fun getTotalShares(): UFix64
        pub fun getHolding(of: Address): UFix64
        pub fun getBalances(): (trump: UFix64, usdf: UFix64)
        pub fun getTrumpVaultType(): Type
        pub fun getUsdfVaultType(): Type
    }

    access(contract) fun withinTolerance(_ lhs: UFix64, _ rhs: UFix64, tolerance: UFix64): Bool {
        let max = lhs >= rhs ? lhs : rhs
        let min = lhs >= rhs ? rhs : lhs
        return max - min <= tolerance
    }

    pub resource Admin {
        pub fun createIndex(
            creator: Address,
            metadata: IndexMetadata,
            trumpVault: @{FungibleToken.Vault},
            usdfVault: @{FungibleToken.Vault}
        ): IndexID {
            pre {
                trumpVault.getType() != usdfVault.getType(): "Index assets must be distinct"
            }
            let id = Flindex.nextIndexID
            Flindex.nextIndexID = id + 1

            let idx <- create Index(
                id: id,
                creator: creator,
                metadata: metadata,
                trumpVault: <-trumpVault,
                usdfVault: <-usdfVault
            )

            Flindex.indices[id] <-! idx
            emit IndexCreated(id: id, creator: creator)
            return id
        }

        pub fun removeIndex(id: IndexID) {
            let removed <- Flindex.indices.remove(key: id) ?? panic("Index not found")
            destroy removed
        }
    }

    pub resource Index: IndexPublic {
        pub let id: IndexID
        pub let creator: Address
        pub let metadata: IndexMetadata
        access(self) let trumpVaultType: Type
        access(self) let usdfVaultType: Type
        access(self) var trumpVault: @{FungibleToken.Vault}
        access(self) var usdfVault: @{FungibleToken.Vault}
        access(self) var holdings: {Address: UFix64}
        access(self) var totalShares: UFix64

        init(
            id: IndexID,
            creator: Address,
            metadata: IndexMetadata,
            trumpVault: @{FungibleToken.Vault},
            usdfVault: @{FungibleToken.Vault}
        ) {
            self.id = id
            self.creator = creator
            self.metadata = metadata
            self.trumpVaultType = trumpVault.getType()
            self.usdfVaultType = usdfVault.getType()
            self.trumpVault <- trumpVault
            self.usdfVault <- usdfVault
            self.holdings = {}
            self.totalShares = 0.0
        }

        destroy() {
            destroy self.trumpVault
            destroy self.usdfVault
        }

        pub fun getID(): IndexID {
            return self.id
        }

        pub fun getCreator(): Address {
            return self.creator
        }

        pub fun getMetadata(): IndexMetadata {
            return self.metadata
        }

        pub fun getTrumpVaultType(): Type {
            return self.trumpVaultType
        }

        pub fun getUsdfVaultType(): Type {
            return self.usdfVaultType
        }

        pub fun getTotalShares(): UFix64 {
            return self.totalShares
        }

        pub fun getBalances(): (trump: UFix64, usdf: UFix64) {
            return (trump: self.trumpVault.balance, usdf: self.usdfVault.balance)
        }

        pub fun getHolding(of: Address): UFix64 {
            return self.holdings[of] ?? 0.0
        }

        access(self) fun assertHoldingsInvariant() {
            var sum: UFix64 = 0.0
            for key in self.holdings.keys {
                sum = sum + self.holdings[key]!
            }
            assert(
                Flindex.withinTolerance(sum, self.totalShares, tolerance: Flindex.holdingsEpsilon),
                message: "Holdings invariant violated"
            )
        }

        access(self) fun estimateValue(
            balance: UFix64,
            with swapper: &{DeFiActions.Swapper}
        ): UFix64 {
            if balance == 0.0 {
                return 0.0
            }
            let quote = swapper.quoteOut(forProvided: balance, reverse: false)
            return quote.outAmount
        }

        pub fun buy(
            investor: Address,
            payment: @FlowToken.Vault,
            flowToTrump: &{DeFiActions.Swapper},
            flowToUsdf: &{DeFiActions.Swapper},
            trumpToFlow: &{DeFiActions.Swapper},
            usdfToFlow: &{DeFiActions.Swapper}
        ): UFix64 {
            pre {
                payment.balance > 0.0: "Payment must be positive"
                flowToTrump.inType() == Flindex.FlowVaultType: "Invalid Flow→TRUMP swapper input type"
                flowToTrump.outType() == self.trumpVaultType: "Invalid Flow→TRUMP swapper output type"
                flowToUsdf.inType() == Flindex.FlowVaultType: "Invalid Flow→USDF swapper input type"
                flowToUsdf.outType() == self.usdfVaultType: "Invalid Flow→USDF swapper output type"
                trumpToFlow.outType() == Flindex.FlowVaultType: "Invalid TRUMP→Flow swapper output type"
                usdfToFlow.outType() == Flindex.FlowVaultType: "Invalid USDF→Flow swapper output type"
            }

            let navBefore = self.estimateValue(balance: self.trumpVault.balance, with: trumpToFlow)
                + self.estimateValue(balance: self.usdfVault.balance, with: usdfToFlow)

            let pricePerShare = self.totalShares > 0.0 ? navBefore / self.totalShares : 1.0
            let sharesMinted = self.totalShares > 0.0 && pricePerShare > 0.0
                ? payment.balance / pricePerShare
                : payment.balance
            assert(sharesMinted > 0.0, message: "Shares minted is zero")

            let flowAmount = payment.balance
            let flowToTrumpAmount = flowAmount / 2.0
            let flowToUsdfAmount = flowAmount - flowToTrumpAmount

            let trumpFlow <- payment.withdraw(amount: flowToTrumpAmount)
            let trumpQuote = flowToTrump.quoteOut(forProvided: flowToTrumpAmount, reverse: false)
            let trumpVault <- flowToTrump.swap(quote: trumpQuote, inVault: <-trumpFlow)
            self.trumpVault.deposit(from: <-trumpVault)

            let usdfFlow <- payment.withdraw(amount: flowToUsdfAmount)
            let usdfQuote = flowToUsdf.quoteOut(forProvided: flowToUsdfAmount, reverse: false)
            let usdfVault <- flowToUsdf.swap(quote: usdfQuote, inVault: <-usdfFlow)
            self.usdfVault.deposit(from: <-usdfVault)

            assert(payment.balance == 0.0, message: "Residual Flow after swaps")
            destroy payment

            self.totalShares = self.totalShares + sharesMinted
            let current = self.holdings[investor] ?? 0.0
            self.holdings[investor] = current + sharesMinted
            self.assertHoldingsInvariant()

            emit IndexBought(id: self.id, user: investor, flowIn: flowAmount, sharesOut: sharesMinted)
            return sharesMinted
        }

        pub fun sell(
            investor: Address,
            shares: UFix64,
            flowToTrump: &{DeFiActions.Swapper},
            flowToUsdf: &{DeFiActions.Swapper},
            trumpToFlow: &{DeFiActions.Swapper},
            usdfToFlow: &{DeFiActions.Swapper}
        ): @FlowToken.Vault {
            pre {
                shares > 0.0: "Shares must be positive"
                shares <= self.holdings[investor] ?? 0.0: "Insufficient shares"
                trumpToFlow.outType() == Flindex.FlowVaultType: "Invalid TRUMP→Flow swapper output type"
                usdfToFlow.outType() == Flindex.FlowVaultType: "Invalid USDF→Flow swapper output type"
            }

            assert(self.totalShares > 0.0, message: "No shares in circulation")

            let navBefore = self.estimateValue(balance: self.trumpVault.balance, with: trumpToFlow)
                + self.estimateValue(balance: self.usdfVault.balance, with: usdfToFlow)
            assert(navBefore > 0.0, message: "Cannot redeem from empty index")

            let shareRatio = shares / self.totalShares

            let trumpAmount = self.trumpVault.balance * shareRatio
            let usdfAmount = self.usdfVault.balance * shareRatio

            let trumpSlice <- self.trumpVault.withdraw(amount: trumpAmount)
            let trumpQuote = trumpToFlow.quoteOut(forProvided: trumpAmount, reverse: false)
            var flowVault <- trumpToFlow.swap(quote: trumpQuote, inVault: <-trumpSlice)

            let usdfSlice <- self.usdfVault.withdraw(amount: usdfAmount)
            let usdfQuote = usdfToFlow.quoteOut(forProvided: usdfAmount, reverse: false)
            let flowFromUsdf <- usdfToFlow.swap(quote: usdfQuote, inVault: <-usdfSlice)

            flowVault.deposit(from: <-flowFromUsdf)

            self.totalShares = self.totalShares - shares
            let current = self.holdings[investor] ?? 0.0
            let remaining = current - shares
            if remaining <= Flindex.holdingsEpsilon {
                self.holdings.remove(key: investor)
            } else {
                self.holdings[investor] = remaining
            }
            self.assertHoldingsInvariant()

            emit IndexSold(id: self.id, user: investor, sharesIn: shares, flowOut: flowVault.balance)
            return <-flowVault
        }
    }

    pub fun borrowIndex(id: IndexID): &Index {
        let ref = &self.indices[id] as &Index?
        if ref == nil {
            panic("Index not found")
        }
        return ref!
    }

    pub fun borrowIndexPublic(id: IndexID): &Index{IndexPublic}? {
        return &self.indices[id] as &Index{IndexPublic}?
    }

    pub fun getIndexIDs(): [IndexID] {
        return self.indices.keys
    }

    pub resource UserPositions {
        pub var holdings: {IndexID: UFix64}

        init() {
            self.holdings = {}
        }

        pub fun set(id: IndexID, shares: UFix64) {
            if shares == 0.0 {
                self.holdings.remove(key: id)
            } else {
                self.holdings[id] = shares
            }
        }

        pub fun get(id: IndexID): UFix64 {
            return self.holdings[id] ?? 0.0
        }

        pub fun getAll(): {IndexID: UFix64} {
            return self.holdings
        }
    }

    pub fun createUserPositions(): @UserPositions {
        return <-create UserPositions()
    }

    init() {
        self.AdminStoragePath = /storage/flindexAdmin
        self.AdminPrivatePath = /private/flindexAdmin
        self.FlowVaultType = Type<@FlowToken.Vault>()
        self.UserPositionsStoragePath = /storage/flindexPositions
        self.UserPositionsPublicPath = /public/flindexPositions
        self.holdingsEpsilon = 0.00000001
        self.nextIndexID = 1
        self.indices <- {}

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
        self.account.link<&Admin>(self.AdminPrivatePath, target: self.AdminStoragePath)
    }

    destroy() {
        destroy self.indices
    }
}

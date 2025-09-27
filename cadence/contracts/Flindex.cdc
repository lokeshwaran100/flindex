import "FungibleToken"
import "FlowToken"
import "DeFiActions"

/// Flindex is a decentralized on-chain crypto index fund composed of TRUMP and USDF tokens.
/// Investors contribute Flow and receive shares that represent proportional ownership in the
/// underlying vaults. Flow contributions are split evenly between TRUMP and USDF during buys,
/// and redemptions exit proportionally from both assets.
access(all) contract Flindex {

    access(all) let AdminStoragePath: StoragePath
    access(all) let AdminPrivatePath: PrivatePath
    access(all) let FlowVaultType: Type
    access(all) let UserPositionsStoragePath: StoragePath
    access(all) let UserPositionsPublicPath: PublicPath
    access(all) let holdingsEpsilon: UFix64

    access(self) var nextIndexID: UInt64
    access(self) var indices: @{UInt64: Index}

    access(all) event IndexCreated(id: UInt64, creator: Address)
    access(all) event IndexBought(id: UInt64, user: Address, flowIn: UFix64, sharesOut: UFix64)
    access(all) event IndexSold(id: UInt64, user: Address, sharesIn: UFix64, flowOut: UFix64)

    access(all) struct IndexMetadata {
        access(all) let name: String
        access(all) let description: String
        access(all) let managementFeeBps: UInt64
        access(all) let createdAt: UFix64

        init(name: String, description: String, managementFeeBps: UInt64, createdAt: UFix64) {
            self.name = name
            self.description = description
            self.managementFeeBps = managementFeeBps
            self.createdAt = createdAt
        }
    }

    access(all) struct IndexBalances {
        access(all) let trump: UFix64
        access(all) let usdf: UFix64

        init(trump: UFix64, usdf: UFix64) {
            self.trump = trump
            self.usdf = usdf
        }
    }

    access(all) resource interface IndexPublic {
        access(all) fun getID(): UInt64
        access(all) fun getCreator(): Address
        access(all) fun getMetadata(): IndexMetadata
        access(all) fun getTotalShares(): UFix64
        access(all) fun getHolding(of: Address): UFix64
        access(all) fun getBalances(): IndexBalances
        access(all) fun getTrumpVaultType(): Type
        access(all) fun getUsdfVaultType(): Type
    }

    access(contract) fun withinTolerance(_ lhs: UFix64, _ rhs: UFix64, tolerance: UFix64): Bool {
        let max = lhs >= rhs ? lhs : rhs
        let min = lhs >= rhs ? rhs : lhs
        return max - min <= tolerance
    }

    access(all) resource Admin {
        access(all) fun createIndex(
            creator: Address,
            metadata: IndexMetadata,
            trumpVault: @{FungibleToken.Vault},
            usdfVault: @{FungibleToken.Vault}
        ): UInt64 {
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

        access(all) fun removeIndex(id: UInt64) {
            let removed <- Flindex.indices.remove(key: id) ?? panic("Index not found")
            destroy removed
        }
    }

    access(all) resource Index: IndexPublic {
        access(all) let id: UInt64
        access(all) let creator: Address
        access(all) let metadata: IndexMetadata
        access(self) let trumpVaultType: Type
        access(self) let usdfVaultType: Type
        access(self) var trumpVault: @{FungibleToken.Vault}
        access(self) var usdfVault: @{FungibleToken.Vault}
        access(self) var holdings: {Address: UFix64}
        access(self) var totalShares: UFix64

        init(
            id: UInt64,
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

        access(all) fun getID(): UInt64 {
            return self.id
        }

        access(all) fun getCreator(): Address {
            return self.creator
        }

        access(all) fun getMetadata(): IndexMetadata {
            return self.metadata
        }

        access(all) fun getTrumpVaultType(): Type {
            return self.trumpVaultType
        }

        access(all) fun getUsdfVaultType(): Type {
            return self.usdfVaultType
        }

        access(all) fun getTotalShares(): UFix64 {
            return self.totalShares
        }

        access(all) fun getBalances(): IndexBalances {
            return IndexBalances(
                trump: self.trumpVault.balance,
                usdf: self.usdfVault.balance
            )
        }

        access(all) fun getHolding(of: Address): UFix64 {
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

        access(all) fun buy(
            investor: Address,
            payment: @FlowToken.Vault,
            flowToTrump: &{DeFiActions.Swapper},
            flowToUsdf: &{DeFiActions.Swapper},
            trumpToFlow: &{DeFiActions.Swapper},
            usdfToFlow: &{DeFiActions.Swapper}
        ): UFix64 {
            pre {
                payment.balance > 0.0: "Payment must be positive"
                flowToTrump.inType() == Flindex.FlowVaultType: "Invalid Flow->TRUMP swapper input type"
                flowToTrump.outType() == self.trumpVaultType: "Invalid Flow->TRUMP swapper output type"
                flowToUsdf.inType() == Flindex.FlowVaultType: "Invalid Flow->USDF swapper input type"
                flowToUsdf.outType() == self.usdfVaultType: "Invalid Flow->USDF swapper output type"
                trumpToFlow.outType() == Flindex.FlowVaultType: "Invalid TRUMP->Flow swapper output type"
                usdfToFlow.outType() == Flindex.FlowVaultType: "Invalid USDF->Flow swapper output type"
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

        access(all) fun sell(
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
                trumpToFlow.outType() == Flindex.FlowVaultType: "Invalid TRUMP->Flow swapper output type"
                usdfToFlow.outType() == Flindex.FlowVaultType: "Invalid USDF->Flow swapper output type"
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
                let _ = self.holdings.remove(key: investor)
            } else {
                self.holdings[investor] = remaining
            }
            self.assertHoldingsInvariant()

            emit IndexSold(id: self.id, user: investor, sharesIn: shares, flowOut: flowVault.balance)
            return <-flowVault as! @FlowToken.Vault
        }
    }

    access(all) fun borrowIndex(id: UInt64): &Index {
        let ref = &self.indices[id] as &Index?
        if ref == nil {
            panic("Index not found")
        }
        return ref!
    }

    access(all) fun borrowIndexPublic(id: UInt64): &Index? {
        if let indexRef = &self.indices[id] as &Index? {
            return indexRef
        }
        return nil
    }

    access(all) fun getIndexIDs(): [UInt64] {
        return self.indices.keys
    }

    access(all) resource UserPositions {
        access(all) var holdings: {UInt64: UFix64}

        init() {
            self.holdings = {}
        }

        access(all) fun set(id: UInt64, shares: UFix64) {
            if shares == 0.0 {
                let _ = self.holdings.remove(key: id)
            } else {
                self.holdings[id] = shares
            }
        }

        access(all) fun get(id: UInt64): UFix64 {
            return self.holdings[id] ?? 0.0
        }

        access(all) fun getAll(): {UInt64: UFix64} {
            return self.holdings
        }
    }

    access(all) fun createUserPositions(): @UserPositions {
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

        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }

}

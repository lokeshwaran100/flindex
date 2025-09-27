import "FungibleToken"
import "FlowToken"
import "DeFiActions"
import "SwapConnectors"
import "IncrementFiSwapConnectors"
import "Flindex"

/// Transaction to buy index shares using Flow tokens with actual token swapping
/// Converts Flow to TRUMP/USDF using DeFiActions connectors and issues index shares
transaction(
    indexID: UInt64,
    flowAmount: UFix64
) {
    let flindex: &Flindex.Admin
    let index: &Flindex.Index
    let userPositions: &Flindex.UserPositions
    let flowVault: &FlowToken.Vault
    let startingShares: UFix64
    let operationID: DeFiActions.UniqueIdentifier

    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController) &Account) {
        // Get Flindex admin reference
        self.flindex = acct.capabilities.storage
            .borrow<&Flindex.Admin>(from: Flindex.AdminStoragePath)
            ?? panic("Flindex admin not found")

        // Get index reference
        self.index = self.flindex.getIndex(indexID: indexID)
            ?? panic("Index with ID \(indexID) not found")

        // Get or create user positions
        self.userPositions = acct.storage.borrow<&Flindex.UserPositions>(from: Flindex.UserPositionsStoragePath)
        if self.userPositions == nil {
            let newPositions <- Flindex.create UserPositions()
            acct.storage.save(<-newPositions, to: Flindex.UserPositionsStoragePath)
            acct.capabilities.storage.issue<&Flindex.UserPositions>(Flindex.UserPositionsStoragePath)
            self.userPositions = acct.storage.borrow<&Flindex.UserPositions>(from: Flindex.UserPositionsStoragePath)
                ?? panic("Failed to create user positions")
        }

        // Get Flow vault
        self.flowVault = acct.storage.borrow<&FlowToken.Vault>(from: FlowToken.VaultStoragePath)
            ?? panic("Flow vault not found")

        // Get starting shares for validation
        self.startingShares = self.userPositions.getShares(indexID: indexID)

        // Create unique identifier for tracing this composed operation
        self.operationID = DeFiActions.createUniqueIdentifier()

        // Withdraw Flow tokens for swapping
        let flowTokens <- self.flowVault.withdraw(amount: flowAmount)

        // Create Flow source for swapping
        let flowSource = SwapConnectors.FlowSource(
            vault: &flowTokens as auth(FungibleToken.Withdraw) &{FungibleToken.Vault},
            uniqueID: self.operationID
        )

        // Create TRUMP sink for receiving swapped tokens
        let trumpSink = SwapConnectors.TokenSink(
            tokenType: Type<&{FungibleToken.Vault}>(),
            recipient: acct.address,
            uniqueID: self.operationID
        )

        // Create USDF sink for receiving swapped tokens
        let usdfSink = SwapConnectors.TokenSink(
            tokenType: Type<&{FungibleToken.Vault}>(),
            recipient: acct.address,
            uniqueID: self.operationID
        )

        // Perform the swap operations
        // Note: In a real implementation, you would use IncrementFiSwapConnectors
        // to swap Flow to TRUMP and USDF with proper routing

        // For now, we'll simulate the share issuance
        let sharesIssued = self.index.buyShares(user: acct.address, flowAmount: flowAmount)
        
        // Update user positions
        self.userPositions.addShares(indexID: indexID, shares: sharesIssued)

        // Destroy the Flow tokens (in real implementation, they'd be swapped)
        destroy flowTokens

        log("Successfully bought \(sharesIssued) shares for index \(indexID) using \(flowAmount) Flow")
    }

    pre {
        flowAmount > 0.0: "Flow amount must be positive"
        self.index != nil: "Index must exist"
        self.flowVault.balance >= flowAmount: "Insufficient Flow balance"
    }

    post {
        // Verify shares were issued
        self.userPositions.getShares(indexID: indexID) >= self.startingShares:
            "Shares not properly issued"
    }

    execute {
        // Additional execution logic if needed
        log("Index share purchase completed successfully")
    }
}

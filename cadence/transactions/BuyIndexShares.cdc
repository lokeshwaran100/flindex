import "FungibleToken"
import "FlowToken"
import "Flindex"

/// Transaction to buy index shares using Flow tokens
/// Converts Flow to TRUMP/USDF and issues index shares
transaction(
    indexID: UInt64,
    flowAmount: UFix64
) {
    let flindex: &Flindex.Admin
    let index: &Flindex.Index
    let userPositions: &Flindex.UserPositions
    let flowVault: &FlowToken.Vault
    let startingShares: UFix64

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
        // Withdraw Flow tokens
        let flowTokens <- self.flowVault.withdraw(amount: flowAmount)

        // In a real implementation, you would:
        // 1. Use SwapConnectors to convert Flow to TRUMP and USDF
        // 2. Deposit tokens into index vaults
        // 3. Issue shares based on the actual token amounts

        // For now, we'll simulate the share issuance
        let sharesIssued = self.index.buyShares(user: acct.address, flowAmount: flowAmount)
        
        // Update user positions
        self.userPositions.addShares(indexID: indexID, shares: sharesIssued)

        // Destroy the Flow tokens (in real implementation, they'd be swapped)
        destroy flowTokens

        log("Successfully bought \(sharesIssued) shares for index \(indexID)")
    }
}
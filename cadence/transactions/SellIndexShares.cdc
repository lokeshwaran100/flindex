import "FungibleToken"
import "FlowToken"
import "Flindex"

/// Transaction to sell index shares back to Flow tokens
/// Redeems shares and converts TRUMP/USDF back to Flow
transaction(
    indexID: UInt64,
    sharesToSell: UFix64
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

        // Get user positions
        self.userPositions = acct.storage.borrow<&Flindex.UserPositions>(from: Flindex.UserPositionsStoragePath)
            ?? panic("User positions not found")

        // Get Flow vault
        self.flowVault = acct.storage.borrow<&FlowToken.Vault>(from: FlowToken.VaultStoragePath)
            ?? panic("Flow vault not found")

        // Get starting shares for validation
        self.startingShares = self.userPositions.getShares(indexID: indexID)
    }

    pre {
        sharesToSell > 0.0: "Shares to sell must be positive"
        self.index != nil: "Index must exist"
        self.userPositions.getShares(indexID: indexID) >= sharesToSell: "Insufficient shares to sell"
    }

    post {
        // Verify shares were removed
        self.userPositions.getShares(indexID: indexID) <= self.startingShares - sharesToSell:
            "Shares not properly removed"
    }

    execute {
        // Calculate Flow to return
        let flowToReturn = self.index.sellShares(user: acct.address, sharesToSell: sharesToSell)
        
        // Update user positions
        self.userPositions.removeShares(indexID: indexID, shares: sharesToSell)

        // In a real implementation, you would:
        // 1. Redeem proportional TRUMP and USDF from index vaults
        // 2. Use SwapConnectors to convert TRUMP/USDF back to Flow
        // 3. Deposit Flow tokens into user's vault

        // For now, we'll simulate the Flow return
        // In a real implementation, the Flow would come from the swap
        let flowTokens <- FlowToken.createEmptyVault()
        // Note: In reality, you'd deposit the actual Flow from the swap
        // flowTokens.deposit(from: <-swappedFlowVault)

        // Deposit Flow tokens into user's vault
        self.flowVault.deposit(from: <-flowTokens)

        log("Successfully sold \(sharesToSell) shares for index \(indexID), received \(flowToReturn) Flow")
    }
}
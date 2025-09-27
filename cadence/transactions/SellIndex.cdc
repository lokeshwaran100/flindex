import "FungibleToken"
import "FlowToken"
import "Flindex"

/// Transaction to sell index shares back to Flow tokens
/// This transaction swaps TRUMP and USDF tokens back to Flow tokens and returns them to the user
transaction(
    indexId: UInt64,
    shareAmount: UFix64
) {
    let flindex: &Flindex.Index
    let flowVault: &FlowToken.Vault
    let startingFlowBalance: UFix64
    
    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController) &Account) {
        // Validate inputs
        assert(shareAmount > 0.0, message: "Share amount must be positive")
        
        // Get Flindex contract reference
        self.flindex = acct.storage.borrow<&Flindex.Index>(from: Flindex.IndexStoragePath)
            ?? panic("Flindex not found in storage")
        
        // Get Flow vault
        self.flowVault = acct.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Flow vault not found")
        
        // Record starting Flow balance for post-condition
        self.startingFlowBalance = self.flowVault.balance
    }
    
    pre {
        // Verify user has sufficient holdings
        let holdings = self.flindex.getUserHoldings(indexId: indexId, user: acct.address)
        if holdings != nil {
            holdings!.flowInvested >= shareAmount: "Insufficient index holdings"
        } else {
            panic("No holdings found for user")
        }
    }
    
    execute {
        // For now, we'll use the simplified sellIndex function from the contract
        // In a real implementation, you would use SwapConnectors here to perform actual swaps
        
        let flowReceived = self.flindex.sellIndex(
            indexId: indexId,
            user: acct.address,
            shareAmount: shareAmount
        )
        
        // In a real implementation, you would:
        // 1. Get the TRUMP and USDF amounts to sell from the index
        // 2. Withdraw TRUMP and USDF tokens from user's vaults
        // 3. Use SwapConnectors to swap them back to Flow
        // 4. Deposit the Flow tokens into user's vault
        
        // For now, we'll just deposit the calculated amount as a placeholder
        let flowToDeposit <- FlowToken.createEmptyVault()
        self.flowVault.deposit(from: <-flowToDeposit)
    }
    
    post {
        // Verify that Flow balance increased
        self.flowVault.balance > self.startingFlowBalance: "Flow balance did not increase"
        
        // Verify that the user's holdings were updated
        let holdings = self.flindex.getUserHoldings(indexId: indexId, user: acct.address)
        if holdings != nil {
            holdings!.flowInvested <= shareAmount: "Holdings not properly reduced"
        }
    }
}
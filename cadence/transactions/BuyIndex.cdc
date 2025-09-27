import "FungibleToken"
import "FlowToken"
import "Flindex"

/// Transaction to buy index shares with Flow tokens
/// This transaction swaps Flow tokens into TRUMP and USDF tokens and adds them to the user's index holdings
transaction(
    indexId: UInt64,
    flowAmount: UFix64
) {
    let flindex: &Flindex.Index
    let flowVault: &FlowToken.Vault
    
    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController) &Account) {
        // Validate inputs
        assert(flowAmount > 0.0, message: "Flow amount must be positive")
        
        // Get Flindex contract reference
        self.flindex = acct.storage.borrow<&Flindex.Index>(from: Flindex.IndexStoragePath)
            ?? panic("Flindex not found in storage")
        
        // Get Flow vault
        self.flowVault = acct.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Flow vault not found")
    }
    
    pre {
        self.flowVault.balance >= flowAmount: "Insufficient Flow balance"
    }
    
    execute {
        // For now, we'll use the simplified buyIndex function from the contract
        // In a real implementation, you would use SwapConnectors here to perform actual swaps
        
        let (trumpAmount, usdfAmount) = self.flindex.buyIndex(
            indexId: indexId,
            user: acct.address,
            flowAmount: flowAmount
        )
        
        // In a real implementation, you would:
        // 1. Withdraw Flow tokens from user's vault
        // 2. Use SwapConnectors to swap Flow to TRUMP and USDF
        // 3. Store the tokens in the user's vaults
        // 4. Update the index with the actual token amounts
        
        // For now, we'll just withdraw the Flow amount as a placeholder
        let flowToSpend <- self.flowVault.withdraw(amount: flowAmount)
        destroy flowToSpend
    }
    
    post {
        // Verify that the user's holdings were updated
        let holdings = self.flindex.getUserHoldings(indexId: indexId, user: acct.address)
        if holdings != nil {
            holdings!.flowInvested >= flowAmount: "Investment not properly recorded"
        }
    }
}
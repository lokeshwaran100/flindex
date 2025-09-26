import FlindexCore from "../contracts/FlindexCore.cdc"
import FlowToken from 0x0ae53cb6e3f42a79

/// Transaction to sell index tokens for Flow tokens
transaction(indexId: UInt64, tokenAmount: UFix64) {
    let collection: &FlindexCore.Collection
    let flowVault: &FlowToken.Vault
    
    prepare(signer: auth(Storage) &Account) {
        // Get reference to IndexToken collection
        self.collection = signer.storage.borrow<&FlindexCore.Collection>(from: FlindexCore.CollectionStoragePath)
            ?? panic("Could not borrow IndexToken collection")
        
        // Get reference to Flow token vault
        self.flowVault = signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow Flow token vault")
    }
    
    execute {
        // Validate input parameters
        assert(tokenAmount > 0.0, message: "Token amount must be positive")
        assert(
            self.collection.getBalance(indexId: indexId) >= tokenAmount,
            message: "Insufficient index token balance"
        )
        
        // Withdraw index tokens
        let indexTokens <- self.collection.withdraw(indexId: indexId, amount: tokenAmount)
        
        // Sell tokens for Flow
        let flowReceived = FlindexCore.sellIndex(
            seller: self.collection.owner!.address,
            tokens: <- indexTokens
        )
        
        // In a real implementation, Flow tokens would be deposited back to user's vault
        // For now, we'll just log the amount received
        log("Successfully sold ".concat(tokenAmount.toString()).concat(" index tokens for ").concat(flowReceived.toString()).concat(" Flow"))
    }
}

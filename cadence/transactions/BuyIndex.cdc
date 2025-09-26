import FlindexCore from "../contracts/FlindexCore.cdc"
import FlowToken from 0x0ae53cb6e3f42a79

/// Transaction to buy index tokens with Flow tokens
transaction(indexId: UInt64, flowAmount: UFix64) {
    let flowVault: &FlowToken.Vault
    let collection: &FlindexCore.Collection
    
    prepare(signer: auth(Storage) &Account) {
        // Get reference to Flow token vault
        self.flowVault = signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow Flow token vault")
        
        // Get reference to IndexToken collection
        self.collection = signer.storage.borrow<&FlindexCore.Collection>(from: FlindexCore.CollectionStoragePath)
            ?? panic("Could not borrow IndexToken collection. Please setup account first.")
    }
    
    execute {
        // Validate input parameters
        assert(flowAmount > 0.0, message: "Flow amount must be positive")
        assert(self.flowVault.balance >= flowAmount, message: "Insufficient Flow balance")
        
        // Withdraw Flow tokens for purchase
        let flowPayment <- self.flowVault.withdraw(amount: flowAmount) as! @FlowToken.Vault
        
        // Buy index tokens
        let indexTokens <- FlindexCore.buyIndex(
            buyer: self.collection.owner!.address,
            indexId: indexId,
            flowAmount: flowAmount
        )
        
        // Deposit tokens into collection
        self.collection.deposit(token: <- indexTokens)
        
        // In a real implementation, the Flow payment would be processed
        // For now, we'll just destroy it (this is for testing)
        destroy flowPayment
        
        log("Successfully purchased index tokens for index ID: ".concat(indexId.toString()))
    }
}

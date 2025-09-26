import FlindexCreator from "../contracts/FlindexCreator.cdc"

/// Transaction for a creator to rebalance an existing index
transaction(
    indexId: UInt64,
    btcPercentage: UFix64,
    ethPercentage: UFix64,
    flowPercentage: UFix64,
    usdcPercentage: UFix64
) {
    let creatorRef: &FlindexCreator.Creator
    
    prepare(signer: auth(Storage) &Account) {
        // Get reference to creator resource
        self.creatorRef = signer.storage.borrow<&FlindexCreator.Creator>(
            from: FlindexCreator.CreatorStoragePath
        ) ?? panic("Creator resource not found")
    }
    
    execute {
        // Create new composition dictionary
        let newComposition: {String: UFix64} = {
            "BTC": btcPercentage,
            "ETH": ethPercentage,
            "FLOW": flowPercentage,
            "USDC": usdcPercentage
        }
        
        // Verify percentages sum to 1.0
        var total: UFix64 = 0.0
        for percentage in newComposition.values {
            total = total + percentage
        }
        assert(total >= 0.99 && total <= 1.01, message: "Asset percentages must sum to 100%")
        
        // Rebalance the index
        FlindexCreator.rebalanceIndexAsCreator(
            creatorRef: self.creatorRef,
            indexId: indexId,
            newComposition: newComposition
        )
        
        log("Index ".concat(indexId.toString()).concat(" rebalanced successfully"))
    }
}

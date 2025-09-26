import FlindexCore from "../contracts/FlindexCore.cdc"
import FlindexCreator from "../contracts/FlindexCreator.cdc"

/// Transaction for a creator to create a new index
/// Requires the creator to have sufficient project tokens staked
/// Only supports TRUMP and USDF tokens
transaction(
    name: String,
    description: String,
    trumpPercentage: UFix64,
    usdfPercentage: UFix64
) {
    let creatorRef: &FlindexCreator.Creator
    
    prepare(signer: auth(Storage) &Account) {
        // Get reference to creator resource
        self.creatorRef = signer.storage.borrow<&FlindexCreator.Creator>(
            from: FlindexCreator.CreatorStoragePath
        ) ?? panic("Creator resource not found. Please register as creator first.")
    }
    
    execute {
        // Validate input parameters
        assert(name.length > 0, message: "Index name cannot be empty")
        assert(description.length > 0, message: "Index description cannot be empty")
        
        // Create composition dictionary
        let composition: {String: UFix64} = {
            "TRUMP": trumpPercentage,
            "USDF": usdfPercentage
        }
        
        // Verify percentages sum to 1.0
        var total: UFix64 = 0.0
        for percentage in composition.values {
            total = total + percentage
        }
        assert(total >= 0.99 && total <= 1.01, message: "Asset percentages must sum to 100%")
        
        // Create the index
        let indexId = FlindexCreator.createIndexAsCreator(
            creatorRef: self.creatorRef,
            name: name,
            description: description,
            composition: composition
        )
        
        log("Index created successfully with ID: ".concat(indexId.toString()))
    }
}

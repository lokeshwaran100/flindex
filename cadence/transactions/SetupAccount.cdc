import FlindexCore from "../contracts/FlindexCore.cdc"

/// Transaction to set up a user account with an IndexToken collection
transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Check if collection already exists
        if signer.storage.borrow<&FlindexCore.Collection>(from: FlindexCore.CollectionStoragePath) == nil {
            // Create new collection
            let collection <- FlindexCore.createEmptyCollection()
            
            // Store collection in account storage
            signer.storage.save(<-collection, to: FlindexCore.CollectionStoragePath)
            
            // Create and publish public capability
            signer.capabilities.unpublish(FlindexCore.CollectionPublicPath)
            let cap = signer.capabilities.storage.issue<&FlindexCore.Collection>(FlindexCore.CollectionStoragePath)
            signer.capabilities.publish(cap, at: FlindexCore.CollectionPublicPath)
        }
    }
    
    execute {
        log("Account setup completed successfully")
    }
}

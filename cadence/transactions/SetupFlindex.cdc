import "Flindex"

/// Transaction to set up the Flindex contract in an account
transaction() {
    let flindex: &Flindex.Index
    
    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, UnpublishCapability, PublishCapability) &Account) {
        // Check if Flindex is already set up
        if acct.storage.borrow<&Flindex.Index>(from: Flindex.IndexStoragePath) == nil {
            // Create and save the Flindex resource
            let flindexResource <- create Flindex.Index(indexId: 0, creator: acct.address)
            acct.storage.save(<-flindexResource, to: Flindex.IndexStoragePath)
            
            // Publish the public capability
            acct.capabilities.unpublish(Flindex.IndexPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&Flindex.Index>(Flindex.IndexStoragePath),
                at: Flindex.IndexPublicPath
            )
        }
        
        // Get reference to the Flindex resource
        self.flindex = acct.storage.borrow<&Flindex.Index>(from: Flindex.IndexStoragePath)
            ?? panic("Failed to get Flindex reference")
    }
    
    execute {
        // Setup is complete
    }
    
    post {
        // Verify that Flindex is properly set up
        self.flindex != nil: "Flindex not properly initialized"
    }
}
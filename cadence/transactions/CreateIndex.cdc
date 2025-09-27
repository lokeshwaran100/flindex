import "Flindex"

/// Transaction to create a new index fund
transaction() {
    let flindex: &Flindex.Index
    let indexId: UInt64
    
    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController) &Account) {
        // Get Flindex contract reference
        self.flindex = acct.storage.borrow<&Flindex.Index>(from: Flindex.IndexStoragePath)
            ?? panic("Flindex not found in storage")
        
        // Create the index
        self.indexId = self.flindex.createIndex(creator: acct.address)
    }
    
    execute {
        // Index creation is handled in the prepare block
        // The index is now available for users to invest in
    }
    
    post {
        // Verify that the index was created
        let indexInfo = self.flindex.getIndexInfo(indexId: self.indexId)
        indexInfo != nil: "Index was not created"
        indexInfo!.creator == acct.address: "Index creator mismatch"
    }
}
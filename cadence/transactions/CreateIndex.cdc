import "FungibleToken"
import "FlowToken"
import "Flindex"

/// Transaction to create a new index fund
/// Sets up a new index with TRUMP/USDF composition
transaction() {
    let flindex: &Flindex.Admin
    let newIndexID: UInt64

    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController) &Account) {
        // Get Flindex admin reference
        self.flindex = acct.capabilities.storage
            .borrow<&Flindex.Admin>(from: Flindex.AdminStoragePath)
            ?? panic("Flindex admin not found")

        // Create new index
        self.newIndexID = self.flindex.createIndex(creator: acct.address)
    }

    post {
        self.newIndexID > 0: "Index ID must be positive"
    }

    execute {
        log("Successfully created index with ID: \(self.newIndexID)")
    }
}
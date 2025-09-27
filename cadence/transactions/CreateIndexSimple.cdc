import "Flindex"

transaction() {
    let admin: &Flindex.Admin

    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController) &Account) {
        // Get admin reference from contract account
        let adminCap = getAccount(0xf8d6e0586b0a20c7)
            .capabilities.get<&Flindex.Admin>(Flindex.AdminPublicPath)
        
        self.admin = adminCap.borrow() ?? panic("Could not borrow admin reference")
    }

    execute {
        let indexID = self.admin.createIndex(creator: 0xf8d6e0586b0a20c7)
        log("Successfully created index with ID: ".concat(indexID.toString()))
    }
}

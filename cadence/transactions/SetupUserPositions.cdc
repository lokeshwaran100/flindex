import "Flindex"

/// Stores the optional Flindex.UserPositions resource in the signer's account and exposes
/// a public capability for read access so off-chain clients can retrieve share balances.
transaction {
    prepare(
        acct: auth(
            BorrowValue,
            SaveValue,
            LoadValue,
            IssueStorageCapabilityController,
            PublishCapability,
            Capabilities
        ) &Account
    ) {
        if acct.storage.borrow<&Flindex.UserPositions>(from: Flindex.UserPositionsStoragePath) == nil {
            acct.storage.save(<-Flindex.createUserPositions(), to: Flindex.UserPositionsStoragePath)
        }

        let positionsCap = acct.capabilities.get<&Flindex.UserPositions>(Flindex.UserPositionsPublicPath)
        if !positionsCap.check() {
            let issued = acct.capabilities.storage
                .issue<&Flindex.UserPositions>(Flindex.UserPositionsStoragePath)
            acct.capabilities.publish(issued, at: Flindex.UserPositionsPublicPath)
        }
    }
}

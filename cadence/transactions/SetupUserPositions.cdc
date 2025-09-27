import "Flindex"

/// Stores the optional Flindex.UserPositions resource in the signer's account and exposes
/// a public capability for read access so off-chain clients can retrieve share balances.
transaction {
    prepare(acct: auth(SaveValue, LoadValue, Capabilities) &Account) {
        if acct.borrow<&Flindex.UserPositions>(from: Flindex.UserPositionsStoragePath) == nil {
            acct.save(<-Flindex.createUserPositions(), to: Flindex.UserPositionsStoragePath)
        }

        let positionsCap = acct.getCapability<&Flindex.UserPositions>(Flindex.UserPositionsPublicPath)
        if !positionsCap.check() {
            acct.link<&Flindex.UserPositions>(
                Flindex.UserPositionsPublicPath,
                target: Flindex.UserPositionsStoragePath
            )
        }
    }
}

import "Flindex"

/// Reads the caller's Flindex share holdings if a UserPositions resource has been set up.
pub fun main(account: Address): {Flindex.IndexID: UFix64} {
    let positionsCap = getAccount(account)
        .getCapability<&Flindex.UserPositions>(Flindex.UserPositionsPublicPath)
    if !positionsCap.check() {
        return {}
    }
    let positions = positionsCap.borrow() ?? panic("Unable to borrow positions reference")
    return positions.getAll()
}

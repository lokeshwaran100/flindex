import "Flindex"

/// Reads the caller's Flindex share holdings if a UserPositions resource has been set up.
access(all) fun main(account: Address): {UInt64: UFix64} {
    let positionsCap = getAccount(account)
        .getCapability<&Flindex.UserPositions>(Flindex.UserPositionsPublicPath)
    if !positionsCap.check() {
        return {}
    }
    let positions = positionsCap.borrow() ?? panic("Unable to borrow positions reference")
    return positions.getAll()
}

import "Flindex"

/// Script to get user's positions across all indices
access(all) fun main(userAddress: Address): [Flindex.UserPosition] {
    let userAccount = getAccount(userAddress)
    let userPositions = userAccount.capabilities.get<&Flindex.UserPositions>(Flindex.UserPositionsPublicPath)
        ?? panic("User positions not found")

    let indices = userPositions.getIndices()
    let positions: [Flindex.UserPosition] = []

    for indexID in indices {
        let shares = userPositions.getShares(indexID: indexID)
        positions.append(Flindex.UserPosition(indexID: indexID, shares: shares))
    }

    return positions
}

/// User position struct
access(all) struct UserPosition {
    access(all) let indexID: UInt64
    access(all) let shares: UFix64

    init(indexID: UInt64, shares: UFix64) {
        self.indexID = indexID
        self.shares = shares
    }
}

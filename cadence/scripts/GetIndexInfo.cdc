import "Flindex"

/// Returns high-level information about a Flindex index including metadata, share supply,
/// and the raw balances held inside the TRUMP and USDF vaults.
access(all) struct IndexInfo {
    access(all) let id: UInt64
    access(all) let name: String
    access(all) let description: String
    access(all) let managementFeeBps: UInt64
    access(all) let totalShares: UFix64
    access(all) let trumpBalance: UFix64
    access(all) let usdfBalance: UFix64

    init(
        id: UInt64,
        name: String,
        description: String,
        managementFeeBps: UInt64,
        totalShares: UFix64,
        trumpBalance: UFix64,
        usdfBalance: UFix64
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.managementFeeBps = managementFeeBps
        self.totalShares = totalShares
        self.trumpBalance = trumpBalance
        self.usdfBalance = usdfBalance
    }
}

access(all) fun main(indexID: UInt64): IndexInfo {
    let indexRef = Flindex.borrowIndexPublic(id: indexID) ?? panic("Index not found")
    let metadata = indexRef.getMetadata()
    let balances = indexRef.getBalances()

    return IndexInfo(
        id: indexRef.getID(),
        name: metadata.name,
        description: metadata.description,
        managementFeeBps: metadata.managementFeeBps,
        totalShares: indexRef.getTotalShares(),
        trumpBalance: balances.trump,
        usdfBalance: balances.usdf
    )
}

import "Flindex"

/// Returns high-level information about a Flindex index including metadata, share supply,
/// and the raw balances held inside the TRUMP and USDF vaults.
pub struct IndexInfo {
    pub let id: Flindex.IndexID
    pub let name: String
    pub let description: String
    pub let managementFeeBps: UInt64
    pub let totalShares: UFix64
    pub let trumpBalance: UFix64
    pub let usdfBalance: UFix64

    init(
        id: Flindex.IndexID,
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

pub fun main(indexID: Flindex.IndexID): IndexInfo {
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

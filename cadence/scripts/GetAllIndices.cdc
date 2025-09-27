import "Flindex"

/// Script to get all active indices
access(all) fun main(): [Flindex.IndexSummary] {
    let flindex = getAccount(Flindex.AdminStoragePath.address)
        .capabilities.get<&Flindex.Admin>(Flindex.AdminPublicPath)
        ?? panic("Flindex admin not found")

    let indices: [Flindex.IndexSummary] = []
    
    // Get all active indices (simplified - in reality you'd iterate through all)
    var indexID: UInt64 = 1
    while indexID < flindex.getNextIndexID() {
        if flindex.isIndexActive(indexID: indexID) {
            let index = flindex.getIndex(indexID: indexID)
            if index != nil {
                indices.append(Flindex.IndexSummary(
                    indexID: index!.indexID,
                    creator: index!.creator,
                    totalShares: index!.totalShares,
                    nav: index!.calculateNAV(),
                    pricePerShare: index!.calculatePricePerShare()
                ))
            }
        }
        indexID = indexID + 1
    }

    return indices
}

/// Index summary struct
access(all) struct IndexSummary {
    access(all) let indexID: UInt64
    access(all) let creator: Address
    access(all) let totalShares: UFix64
    access(all) let nav: UFix64
    access(all) let pricePerShare: UFix64

    init(
        indexID: UInt64,
        creator: Address,
        totalShares: UFix64,
        nav: UFix64,
        pricePerShare: UFix64
    ) {
        self.indexID = indexID
        self.creator = creator
        self.totalShares = totalShares
        self.nav = nav
        self.pricePerShare = pricePerShare
    }
}

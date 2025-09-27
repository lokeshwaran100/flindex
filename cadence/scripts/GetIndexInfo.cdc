import "Flindex"

/// Script to get information about a specific index
access(all) fun main(indexID: UInt64): Flindex.IndexInfo? {
    let flindex = getAccount(Flindex.AdminStoragePath.address)
        .capabilities.get<&Flindex.Admin>(Flindex.AdminPublicPath)
        ?? panic("Flindex admin not found")

    let index = flindex.getIndex(indexID: indexID)
    if index == nil {
        return nil
    }

    return Flindex.IndexInfo(
        indexID: index!.indexID,
        creator: index!.creator,
        totalShares: index!.totalShares,
        nav: index!.calculateNAV(),
        pricePerShare: index!.calculatePricePerShare(),
        holders: index!.getHolders()
    )
}

/// Index information struct
access(all) struct IndexInfo {
    access(all) let indexID: UInt64
    access(all) let creator: Address
    access(all) let totalShares: UFix64
    access(all) let nav: UFix64
    access(all) let pricePerShare: UFix64
    access(all) let holders: [Address]

    init(
        indexID: UInt64,
        creator: Address,
        totalShares: UFix64,
        nav: UFix64,
        pricePerShare: UFix64,
        holders: [Address]
    ) {
        self.indexID = indexID
        self.creator = creator
        self.totalShares = totalShares
        self.nav = nav
        self.pricePerShare = pricePerShare
        self.holders = holders
    }
}

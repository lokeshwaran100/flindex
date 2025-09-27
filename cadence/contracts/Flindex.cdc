import "FungibleToken"
import "FlowToken"

access(all) contract Flindex {

    access(all) event IndexCreated(id: UInt64, creator: Address)
    access(all) event IndexBought(id: UInt64, user: Address, flowIn: UFix64, sharesOut: UFix64)
    access(all) event IndexSold(id: UInt64, user: Address, sharesIn: UFix64, flowOut: UFix64)

    access(all) let AdminStoragePath: StoragePath
    access(all) let UserPositionsStoragePath: StoragePath
    access(all) let IndexStoragePath: StoragePath

    access(all) let AdminPublicPath: PublicPath
    access(all) let UserPositionsPublicPath: PublicPath
    access(all) let IndexPublicPath: PublicPath

    access(all) resource Admin {
        access(all) var nextIndexID: UInt64
        access(all) var activeIndices: {UInt64: Bool}

        init() {
            self.nextIndexID = 1
            self.activeIndices = {}
        }

        access(all) fun createIndex(creator: Address): UInt64 {
            let indexID = self.nextIndexID
            self.nextIndexID = self.nextIndexID + 1
            self.activeIndices[indexID] = true

            emit IndexCreated(id: indexID, creator: creator)
            return indexID
        }

        access(all) fun getNextIndexID(): UInt64 {
            return self.nextIndexID
        }

        access(all) fun isIndexActive(indexID: UInt64): Bool {
            return self.activeIndices[indexID] ?? false
        }
    }

    access(all) resource UserPositions {
        access(all) var positions: {UInt64: UFix64}

        init() {
            self.positions = {}
        }

        access(all) fun addShares(indexID: UInt64, shares: UFix64) {
            self.positions[indexID] = (self.positions[indexID] ?? 0.0) + shares
        }

        access(all) fun removeShares(indexID: UInt64, shares: UFix64) {
            if let currentShares = self.positions[indexID] {
                if currentShares > shares {
                    self.positions[indexID] = currentShares - shares
                } else {
                    self.positions.remove(key: indexID)
                }
            }
        }

        access(all) fun getShares(indexID: UInt64): UFix64 {
            return self.positions[indexID] ?? 0.0
        }

        access(all) fun getIndices(): [UInt64] {
            return self.positions.keys
        }
    }

    init() {
        self.AdminStoragePath = /storage/FlindexAdmin
        self.UserPositionsStoragePath = /storage/FlindexUserPositions
        self.IndexStoragePath = /storage/FlindexIndex
        self.AdminPublicPath = /public/FlindexAdmin
        self.UserPositionsPublicPath = /public/FlindexUserPositions
        self.IndexPublicPath = /public/FlindexIndex

        let admin <- create Admin()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)

        let adminCap = self.account.capabilities.storage.issue<&Admin>(self.AdminStoragePath)
        self.account.capabilities.publish(adminCap, at: self.AdminPublicPath)
    }
}

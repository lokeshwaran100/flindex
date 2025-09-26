import FlindexCore from "../contracts/FlindexCore.cdc"

/// Script to get current valuation of an index using mock Pyth prices
access(all) fun main(indexId: UInt64): UFix64 {
    return FlindexCore.getIndexValuation(indexId: indexId)
}

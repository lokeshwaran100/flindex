import FlindexCore from "../contracts/FlindexCore.cdc"

/// Script to get metadata for a specific index
access(all) fun main(indexId: UInt64): FlindexCore.IndexMetadata? {
    return FlindexCore.getIndexMetadata(indexId: indexId)
}

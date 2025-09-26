import FlindexCore from "../contracts/FlindexCore.cdc"

/// Script to get an account's balance for a specific index
access(all) fun main(account: Address, indexId: UInt64): UFix64 {
    let publicCollection = getAccount(account)
        .capabilities.get<&FlindexCore.Collection>(FlindexCore.CollectionPublicPath)
        .borrow()
        ?? panic("Could not borrow collection reference")
    
    return publicCollection.getBalance(indexId: indexId)
}

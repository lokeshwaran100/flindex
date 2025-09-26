import FlindexCreator from "../contracts/FlindexCreator.cdc"

/// Script to get creator information
access(all) fun main(creator: Address): FlindexCreator.CreatorInfo? {
    return FlindexCreator.getCreatorInfo(creator: creator)
}

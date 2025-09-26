import FlindexCreator from "../contracts/FlindexCreator.cdc"

/// Transaction to register as a creator by staking project tokens
transaction(stakeAmount: UFix64) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Check if already registered
        assert(
            !FlindexCreator.isRegisteredCreator(creator: signer.address),
            message: "Already registered as creator"
        )
        
        // Validate stake amount
        assert(
            stakeAmount >= FlindexCreator.minimumStakeRequired,
            message: "Stake amount must meet minimum requirement"
        )
        
        // Mint project tokens for staking (in production, these would be acquired differently)
        let projectTokens <- FlindexCreator.mintProjectTokens(amount: stakeAmount)
        
        // Register as creator
        let creator <- FlindexCreator.registerCreator(
            creator: signer.address,
            initialStake: <- projectTokens
        )
        
        // Store creator resource
        signer.storage.save(<-creator, to: FlindexCreator.CreatorStoragePath)
        
        // Create and publish public capability
        signer.capabilities.unpublish(FlindexCreator.CreatorPublicPath)
        let cap = signer.capabilities.storage.issue<&FlindexCreator.Creator>(FlindexCreator.CreatorStoragePath)
        signer.capabilities.publish(cap, at: FlindexCreator.CreatorPublicPath)
    }
    
    execute {
        log("Successfully registered as creator with stake: ".concat(stakeAmount.toString()))
    }
}

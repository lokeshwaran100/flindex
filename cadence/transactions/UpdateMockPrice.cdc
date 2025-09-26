import FlindexCore from "../contracts/FlindexCore.cdc"

/// Transaction to update mock asset prices (for testing purposes)
/// In production, this would be replaced by Pyth oracle integration
/// Only supports TRUMP and USDF tokens
transaction(asset: String, price: UFix64) {
    prepare(signer: auth(Storage) &Account) {
        // Only the contract deployer can update prices
        assert(
            signer.address == FlindexCore.account.address,
            message: "Only contract deployer can update mock prices"
        )
    }
    
    execute {
        // Validate inputs
        assert(asset.length > 0, message: "Asset symbol cannot be empty")
        assert(price > 0.0, message: "Price must be positive")
        assert(asset == "TRUMP" || asset == "USDF", message: "Only TRUMP and USDF tokens are supported")
        
        // Update the mock price
        FlindexCore.updateMockPrice(asset: asset, price: price)
        
        log("Updated mock price for ".concat(asset).concat(" to ").concat(price.toString()))
    }
}

import FlindexCore from "../contracts/FlindexCore.cdc"

/// Script to get all available mock asset prices
/// Only supports TRUMP and USDF tokens
access(all) fun main(): {String: UFix64} {
    let assets = ["TRUMP", "USDF"]
    let prices: {String: UFix64} = {}
    
    for asset in assets {
        prices[asset] = FlindexCore.getMockPrice(asset: asset)
    }
    
    return prices
}

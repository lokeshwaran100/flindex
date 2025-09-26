import FlindexCore from "../contracts/FlindexCore.cdc"

/// Script to get all available mock asset prices
access(all) fun main(): {String: UFix64} {
    let assets = ["BTC", "ETH", "FLOW", "USDC", "SOL", "ADA", "DOT", "LINK", "UNI", "AVAX"]
    let prices: {String: UFix64} = {}
    
    for asset in assets {
        prices[asset] = FlindexCore.getMockPrice(asset: asset)
    }
    
    return prices
}

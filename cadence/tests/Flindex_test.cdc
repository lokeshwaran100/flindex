import Test
import BlockchainHelpers
import FlindexCore from "../contracts/FlindexCore.cdc"
import FlindexCreator from "../contracts/FlindexCreator.cdc"
import FlindexTreasury from "../contracts/FlindexTreasury.cdc"

access(all) let admin = Test.getAccount(0x0000000000000007)
access(all) let creator = Test.createAccount()
access(all) let user = Test.createAccount()

access(all) fun setup() {
    let err = Test.deployContract(
        name: "FlindexCore",
        path: "../contracts/FlindexCore.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    let err2 = Test.deployContract(
        name: "FlindexCreator", 
        path: "../contracts/FlindexCreator.cdc",
        arguments: []
    )
    Test.expect(err2, Test.beNil())

    let err3 = Test.deployContract(
        name: "FlindexTreasury",
        path: "../contracts/FlindexTreasury.cdc", 
        arguments: []
    )
    Test.expect(err3, Test.beNil())
}

access(all) fun testCreatorRegistration() {
    // Setup creator account
    let setupCreatorTx = Test.Transaction(
        code: loadCode("../transactions/RegisterCreator.cdc", "transactions"),
        authorizers: [creator.address],
        signers: [creator],
        arguments: [1000.0] // Stake 1000 project tokens
    )
    
    let result = Test.executeTransaction(setupCreatorTx)
    Test.expect(result, Test.beSucceeded())
    
    // Verify creator is registered
    let isRegistered = FlindexCreator.isRegisteredCreator(creator: creator.address)
    Test.expect(isRegistered, Test.beTrue())
    
    // Check creator info
    let creatorInfo = FlindexCreator.getCreatorInfo(creator: creator.address)
    Test.expect(creatorInfo, Test.beNotNil())
    Test.expect(creatorInfo!.stakedTokens, Test.equal(1000.0))
}

access(all) fun testIndexCreation() {
    // First register creator
    testCreatorRegistration()
    
    // Create an index
    let createIndexTx = Test.Transaction(
        code: loadCode("../transactions/CreateIndex.cdc", "transactions"),
        authorizers: [creator.address],
        signers: [creator],
        arguments: [
            "DeFi Index", // name
            "A diversified DeFi index fund", // description
            0.4, // BTC percentage
            0.3, // ETH percentage  
            0.2, // FLOW percentage
            0.1  // USDC percentage
        ]
    )
    
    let result = Test.executeTransaction(createIndexTx)
    Test.expect(result, Test.beSucceeded())
    
    // Verify index was created
    let metadata = FlindexCore.getIndexMetadata(indexId: 1)
    Test.expect(metadata.name, Test.equal("DeFi Index"))
    Test.expect(metadata.creator, Test.equal(creator.address))
    Test.expect(metadata.composition.assets["BTC"], Test.equal(0.4))
}

access(all) fun testAccountSetup() {
    // Setup user account
    let setupAccountTx = Test.Transaction(
        code: loadCode("../transactions/SetupAccount.cdc", "transactions"),
        authorizers: [user.address],
        signers: [user],
        arguments: []
    )
    
    let result = Test.executeTransaction(setupAccountTx)
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testIndexPurchase() {
    // Setup prerequisites
    testIndexCreation()
    testAccountSetup()
    
    // Buy index tokens
    let buyIndexTx = Test.Transaction(
        code: loadCode("../transactions/BuyIndex.cdc", "transactions"),
        authorizers: [user.address],
        signers: [user],
        arguments: [
            UInt64(1), // indexId
            100.0      // flowAmount
        ]
    )
    
    let result = Test.executeTransaction(buyIndexTx)
    Test.expect(result, Test.beSucceeded())
    
    // Verify user has index tokens
    let balance = FlindexCore.getAccountIndexBalance(account: user.address, indexId: 1)
    Test.expect(balance, Test.beGreaterThan(0.0))
}

access(all) fun testIndexValuation() {
    // Setup prerequisites
    testIndexCreation()
    
    // Get index valuation
    let valuation = FlindexCore.getIndexValuation(indexId: 1)
    Test.expect(valuation, Test.beGreaterThan(0.0))
    
    // Update a mock price and verify valuation changes
    FlindexCore.updateMockPrice(asset: "BTC", price: 50000.0)
    let newValuation = FlindexCore.getIndexValuation(indexId: 1)
    Test.expect(newValuation, Test.beGreaterThan(valuation))
}

access(all) fun testTreasuryStats() {
    let stats = FlindexTreasury.getTreasuryStats()
    Test.expect(stats.totalFeesCollected, Test.beGreaterThanOrEqual(0.0))
    Test.expect(stats.transactionsProcessed, Test.beGreaterThanOrEqual(0))
}

// Helper function to load transaction/script code
access(all) fun loadCode(_ name: String, _ type: String): String {
    return Test.readFile("../".concat(type).concat("/").concat(name))
}

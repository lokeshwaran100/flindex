import "FungibleToken"
import "FlowToken"
import "DeFiActions"
import "Flindex"

/// Redeems Flindex shares for Flow by proportionally exiting the TRUMP/USDF vaults and
/// routing the assets through configured swappers. The same connectors used for buying can be
/// reused here when selling.
transaction(
    indexID: UInt64,
    shares: UFix64,
    flowVaultPath: StoragePath,
    flowToTrumpProvider: Address,
    flowToTrumpPath: CapabilityPath,
    flowToUsdfProvider: Address,
    flowToUsdfPath: CapabilityPath,
    trumpToFlowProvider: Address,
    trumpToFlowPath: CapabilityPath,
    usdfToFlowProvider: Address,
    usdfToFlowPath: CapabilityPath
) {
    let index: &Flindex.Index
    let investor: Address
    let flowVault: &FlowToken.Vault
    let positions: &Flindex.UserPositions?

    let flowToTrumpCap: Capability<&{DeFiActions.Swapper}>
    let flowToUsdfCap: Capability<&{DeFiActions.Swapper}>
    let trumpToFlowCap: Capability<&{DeFiActions.Swapper}>
    let usdfToFlowCap: Capability<&{DeFiActions.Swapper}>

    prepare(acct: auth(BorrowValue, SaveValue, Capabilities) &Account) {
        self.index = Flindex.borrowIndex(id: indexID)
        self.investor = acct.address
        self.flowVault = acct.borrow<&FlowToken.Vault>(from: flowVaultPath)
            ?? panic("Flow vault not found at supplied path")
        self.positions = acct.borrow<&Flindex.UserPositions>(from: Flindex.UserPositionsStoragePath)

        self.flowToTrumpCap = getAccount(flowToTrumpProvider)
            .getCapability<&{DeFiActions.Swapper}>(flowToTrumpPath)
        self.flowToUsdfCap = getAccount(flowToUsdfProvider)
            .getCapability<&{DeFiActions.Swapper}>(flowToUsdfPath)
        self.trumpToFlowCap = getAccount(trumpToFlowProvider)
            .getCapability<&{DeFiActions.Swapper}>(trumpToFlowPath)
        self.usdfToFlowCap = getAccount(usdfToFlowProvider)
            .getCapability<&{DeFiActions.Swapper}>(usdfToFlowPath)

        assert(self.flowToTrumpCap.check(), message: "Invalid Flow->TRUMP swapper capability")
        assert(self.flowToUsdfCap.check(), message: "Invalid Flow->USDF swapper capability")
        assert(self.trumpToFlowCap.check(), message: "Invalid TRUMP->Flow swapper capability")
        assert(self.usdfToFlowCap.check(), message: "Invalid USDF->Flow swapper capability")
    }

    execute {
        let flowToTrump = self.flowToTrumpCap.borrow()
            ?? panic("Unable to borrow Flow->TRUMP swapper")
        let flowToUsdf = self.flowToUsdfCap.borrow()
            ?? panic("Unable to borrow Flow->USDF swapper")
        let trumpToFlow = self.trumpToFlowCap.borrow()
            ?? panic("Unable to borrow TRUMP->Flow swapper")
        let usdfToFlow = self.usdfToFlowCap.borrow()
            ?? panic("Unable to borrow USDF->Flow swapper")

        let payout <- self.index.sell(
            investor: self.investor,
            shares: shares,
            flowToTrump: flowToTrump,
            flowToUsdf: flowToUsdf,
            trumpToFlow: trumpToFlow,
            usdfToFlow: usdfToFlow
        )
        self.flowVault.deposit(from: <-payout)

        if let positions = self.positions {
            let current = positions.get(id: indexID)
            let remaining = current - shares
            positions.set(
                id: indexID,
                shares: remaining >= 0.0 ? remaining : 0.0
            )
        }
    }
}

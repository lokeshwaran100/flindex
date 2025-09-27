import "FungibleToken"
import "Flindex"

/// Creates a new Flindex index backed by TRUMP and USDF vaults supplied by the admin account.
/// The admin must already store vaults for the desired assets and provide their storage paths so
/// that empty vault resources can be moved into the contract for custody.
transaction(
    name: String,
    description: String,
    managementFeeBps: UInt64,
    trumpVaultPath: StoragePath,
    usdfVaultPath: StoragePath
) {
    let admin: &Flindex.Admin
    let creator: Address
    var trumpVault: @{FungibleToken.Vault}?
    var usdfVault: @{FungibleToken.Vault}?

    prepare(acct: auth(BorrowValue, SaveValue, LoadValue) &Account) {
        self.admin = acct.borrow<&Flindex.Admin>(from: Flindex.AdminStoragePath)
            ?? panic("Missing Flindex admin resource")
        self.creator = acct.address

        let trumpVault <- acct.load<@{FungibleToken.Vault}>(from: trumpVaultPath)
            ?? panic("TRUMP vault not found at provided path")
        let replacementTrump <- trumpVault.createEmptyVault()
        acct.save(<-replacementTrump, to: trumpVaultPath)
        self.trumpVault <- trumpVault

        let usdfVault <- acct.load<@{FungibleToken.Vault}>(from: usdfVaultPath)
            ?? panic("USDF vault not found at provided path")
        let replacementUsdf <- usdfVault.createEmptyVault()
        acct.save(<-replacementUsdf, to: usdfVaultPath)
        self.usdfVault <- usdfVault
    }

    execute {
        let metadata = Flindex.IndexMetadata(
            name: name,
            description: description,
            managementFeeBps: managementFeeBps,
            createdAt: getCurrentBlock().timestamp
        )

        let indexID = self.admin.createIndex(
            creator: self.creator,
            metadata: metadata,
            trumpVault: <-self.trumpVault!,
            usdfVault: <-self.usdfVault!
        )

        log("Created Flindex index with ID ".concat(indexID.toString()))
    }

    destroy() {
        destroy self.trumpVault
        destroy self.usdfVault
    }
}

import FlindexTreasury from "../contracts/FlindexTreasury.cdc"

/// Script to get treasury statistics
access(all) fun main(): FlindexTreasury.TreasuryStats {
    return FlindexTreasury.getTreasuryStats()
}

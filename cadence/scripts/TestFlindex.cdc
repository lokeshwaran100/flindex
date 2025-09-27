import "Flindex"

/// Simple test script to verify Flindex contract is working
access(all) fun main(): String {
    let indexIDs = Flindex.getIndexIDs()
    return "Flindex contract is working! Found ".concat(indexIDs.length.toString()).concat(" indexes.")
}

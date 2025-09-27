import "Flindex"

/// Returns the list of active Flindex index identifiers.
pub fun main(): [Flindex.IndexID] {
    return Flindex.getIndexIDs()
}

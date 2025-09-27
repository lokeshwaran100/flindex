import "Flindex"

/// Returns the list of active Flindex index identifiers.
access(all) fun main(): [UInt64] {
    return Flindex.getIndexIDs()
}

import java.io.File

fun main() {
    val pairs = readInput("../input.txt")

    val numFullyContained = pairs.filter { pairFullyContains(it) }.size
    println("Fully contained pairs: " + numFullyContained)

    val numAtAllContained = pairs.filter { pairOverlapsAtAll(it) }.size
    println("At all contained pairs: " + numAtAllContained)
}

typealias Section = Pair<Int, Int>
typealias SectionPair = Pair<Section, Section>

fun getSectionsFromLine(line: String): Pair<Section, Section> {
    return line.split(',').map {
        it.split('-').map { it.toInt() }.let { 
            Section(it[0], it[1])
        }
    }.let {
        Pair(it[0], it[1])
    }
}

fun pairFullyContains(pair: SectionPair): Boolean {
    val (s1, s2) = pair
    if (s1.first >= s2.first && s1.second <= s2.second) {
        return true
    }
    if (s2.first >= s1.first && s2.second <= s1.second) {
        return true
    }
    return false
}

fun pairOverlapsAtAll(pair: SectionPair): Boolean {
    val (s1, s2) = pair
    if (s1.first <= s2.first && s1.second >= s2.first) {
        return true
    }
    if (s2.first <= s1.first && s2.second >= s1.first) {
        return true
    }
    return false
}

fun readInput(filepath: String): Array<SectionPair> {
    var pairs = mutableListOf<SectionPair>()

    File(filepath).bufferedReader().forEachLine {
        pairs.add(getSectionsFromLine(it))
    }

    return pairs.toTypedArray()
}

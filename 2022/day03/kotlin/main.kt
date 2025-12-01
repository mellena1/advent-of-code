import java.io.File

fun main() {
    val priorities1 = readInputPt1("../input.txt")
    println("Sum (Pt1): " + priorities1.sum())

    val priorities2 = readInputPt2("../input.txt")
    println("Sum (Pt2): " + priorities2.sum())
}

fun charPriority(c: Char): Int {
    if (c >= 'A' && c <= 'Z') {
        return c.code - 38
    }
    if (c >= 'a' && c <= 'z') {
        return c.code - 96
    }
    throw Exception("not a valid char")
}

fun getLineCharSetIntersect(line: String): Set<Char> {
    val c1 = line.substring(0, line.length/2)
    val c2 = line.substring(line.length/2)

    return c1.toSet().intersect(c2.toSet())
}

fun getPrioritySum(line: String): Int {
    val sameChars = getLineCharSetIntersect(line)
    return sameChars.fold(0){ acc, c -> acc + charPriority(c) }
}

fun readInputPt1(filepath: String): Array<Int> {
    var priorities = mutableListOf<Int>()

    File(filepath).bufferedReader().forEachLine {
        priorities.add(getPrioritySum(it))
    }

    return priorities.toTypedArray()
}

fun readInputPt2(filepath: String): Array<Int> {
    var priorities = mutableListOf<Int>()

    var i = 0
    var chars: Set<Char>? = null
    File(filepath).bufferedReader().forEachLine {
        val newChars = it.toSet()
        chars = chars?.intersect(newChars) ?: newChars

        i++
        if (i == 3) {
            priorities.add(charPriority(chars!!.toTypedArray()[0]))
            i = 0
            chars = null
        }
    }

    return priorities.toTypedArray()
}

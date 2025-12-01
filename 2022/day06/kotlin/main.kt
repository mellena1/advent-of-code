import java.nio.file.Files
import java.nio.file.Paths

fun main() {
    val inputString = readInput("../input.txt")

    // plus one because it's looking for num of chars, not index
    println("Part 1: " + (indexWithNUniqueChars(inputString, 4) + 1))
    println("Part 2: " + (indexWithNUniqueChars(inputString, 14) + 1))
}

fun indexWithNUniqueChars(input: String, numChars: Int): Int {
    val chars = hashMapOf<Char, Int>()

    for (i in 0..input.length-numChars) {
        val c = input[i]
        if (chars.containsKey(c)) {
            chars.put(c, chars.get(c)!! + 1)
        } else {
            chars.put(c, 1)
        }

        if (i < numChars - 1) {
            continue
        }

        if (i > numChars - 1) {
            val cToRemove = input[i-numChars]
            val newVal = chars.get(cToRemove)!! - 1
            if (newVal > 0) {
                chars.put(cToRemove, newVal)
            } else {
                chars.remove(cToRemove)
            }
        }

        if (chars.size == numChars) {
            return i
        }
    }

    return -1
}

fun readInput(filepath: String): String {
    return Files.readString(Paths.get(filepath))
}

import java.io.File

fun main() {
    val caloriesList = readInput("../input.txt")
    caloriesList.sortDescending()

    println("Max: " + caloriesList[0])
    println("Max 3 sum: " + caloriesList.slice(0..2).sum())
}

fun readInput(filepath: String): Array<Int> {
    var amounts = mutableListOf<Int>()
    var acc = 0

    File(filepath).bufferedReader().forEachLine {
        if (it == "") {
            amounts.add(acc)
            acc = 0
        } else {
            acc += it.toInt()
        }
    }

    return amounts.toTypedArray()
}

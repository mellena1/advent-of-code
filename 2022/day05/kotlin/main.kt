import java.io.File
import kotlin.collections.ArrayDeque
import kotlin.collections.mutableListOf

fun main() {
    val (cols, moves) = readInput("../input.txt")
    
    val colsPart1 = cloneColumnList(cols)
    executeMovesPart1(colsPart1, moves)
    print("Part 1: ")
    for (col in colsPart1) {
        print(col.first())
    }

    val colsPart2 = cloneColumnList(cols)
    executeMovesPart2(colsPart2, moves)
    print("\nPart 2: ")
    for (col in colsPart2) {
        print(col.first())
    }
}

data class Move(val crates: Int, val from: Int, val to: Int)

typealias ColumnList = Array<ArrayDeque<Char>>
typealias MoveList = Array<Move>

fun cloneColumnList(cols: ColumnList): ColumnList {
    return cols.map { ArrayDeque<Char>(it.toList()) }.toTypedArray()
}

fun executeMovesPart1(cols: ColumnList, moves: MoveList) {
    for (move in moves) {
        for (i in 1..move.crates) {
            val c = cols[move.from - 1].removeFirst()
            cols[move.to - 1].addFirst(c)
        }
    }
}

fun executeMovesPart2(cols: ColumnList, moves: MoveList) {
    
    for (move in moves) {
        val crates = ArrayDeque<Char>(move.crates)
        for (i in 1..move.crates) {
            val c = cols[move.from - 1].removeFirst()
            crates.addFirst(c)
        }
        for (i in 1..move.crates) {
            cols[move.to - 1].addFirst(crates.removeFirst())
        }
    }
}

fun readInput(filepath: String): Pair<ColumnList, MoveList> {
    var cols: ColumnList? = null;
    var moves = mutableListOf<Move>()

    File(filepath).bufferedReader().forEachLine {
        if (cols == null) {
            cols = Array(it.length / 4 + 1){ ArrayDeque() }
        }

        if (it != "" && it.startsWith("move")) {
            moves.add(parseMove(it))
        } else if (it != "" && !it[0].isDigit()) {
            handleColLine(cols!!, it)
        }
    }

    return Pair(cols!!, moves.toTypedArray())
}

val moveRegex = Regex("""move (\d+) from (\d+) to (\d+)""")

fun parseMove(line: String): Move {
    val match = moveRegex.matchEntire(line)
    val (crates, from, to) = match!!.destructured
    return Move(crates.toInt(), from.toInt(), to.toInt())
}

fun handleColLine(cols: ColumnList, line: String) {
    var i = 1
    while (i < line.length) {
        if (line[i].isLetter()) {
            cols[i/4].addLast(line[i])            
        }
        i += 4
    }
}

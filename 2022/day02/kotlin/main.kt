import java.io.File

fun main() {
    val scores1 = readInput("../input.txt", 1)
    println("Score (pt 1): " + scores1.sum())

    val scores2 = readInput("../input.txt", 2)
    println("Score (pt 2): " + scores2.sum())
}

enum class Result(val score: Int) {
    WIN(6), DRAW(3), LOSS(0)
}

enum class Choice(val score: Int) {
    ROCK(1), PAPER(2), SCISSORS(3);

    companion object {
        fun getResult(c1: Choice, c2: Choice): Result {
            if (c1 == c2) {
                return Result.DRAW
            }
            return when (c1) {
                ROCK -> if (c2 == SCISSORS) Result.WIN else Result.LOSS
                PAPER -> if (c2 == ROCK) Result.WIN else Result.LOSS
                SCISSORS -> if (c2 == PAPER) Result.WIN else Result.LOSS
            }
        }

        fun getNeededChoice(opp: Choice, result: Result): Choice {
            return when (result) {
                Result.DRAW -> opp
                Result.WIN -> when (opp) {
                    ROCK -> PAPER
                    PAPER -> SCISSORS
                    SCISSORS -> ROCK
                }
                Result.LOSS -> when (opp) {
                    ROCK -> SCISSORS
                    PAPER -> ROCK
                    SCISSORS -> PAPER
                }
            }
        }
    }
    
}

fun strToChoicePt1(s: String): Choice {
    return when (s) {
        "A", "X" -> Choice.ROCK
        "B", "Y" -> Choice.PAPER
        "C", "Z" -> Choice.SCISSORS
        else -> throw Exception("invalid string")
    }
}

fun getScorePt1(line: String): Int {
    val (opp, you) = line.split(' ').map {
        strToChoicePt1(it)
    }

    return you.score + Choice.getResult(you, opp).score
}

fun strToChoicePt2(s: String): Choice {
    return when (s) {
        "A" -> Choice.ROCK
        "B" -> Choice.PAPER
        "C" -> Choice.SCISSORS
        else -> throw Exception("invalid string")
    } 
}

fun strToResultPt2(s: String): Result {
    return when (s) {
        "X" -> Result.LOSS
        "Y" -> Result.DRAW
        "Z" -> Result.WIN
        else -> throw Exception("invalid string") 
    }
}

fun getScorePt2(line: String): Int {
    val (opp, result) = line.split(' ').let {
        Pair(strToChoicePt2(it[0]), strToResultPt2(it[1]))
    }
    val you = Choice.getNeededChoice(opp, result)

    return you.score + result.score
}

fun readInput(filepath: String, part: Int): Array<Int> {
    var scores = mutableListOf<Int>()

    File(filepath).bufferedReader().forEachLine {
        scores.add(
            if (part == 1) getScorePt1(it) else getScorePt2(it)
        )
    }

    return scores.toTypedArray()
}

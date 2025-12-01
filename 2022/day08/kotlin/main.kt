import java.io.File

fun main() {
    val grid = readInput("../input.txt")

    val numVisible: Int = grid.foldIndexed(0){ y, acc, next -> acc + next.foldIndexed(0){ x, accInner, _ -> accInner + isVisible(grid, x, y).toInt() } }    
    println("Part 1: " + numVisible)

    val maxScenicScore: Int = grid.mapIndexed { y, row -> row.mapIndexed { x, _ -> scenicScore(grid, x, y) }.max() }.max()
    println("Part 2: " + maxScenicScore)
}

typealias Grid = Array<Array<Int>>
fun Boolean.toInt() = if (this) 1 else 0

fun isVisible(grid: Grid, x: Int, y: Int): Boolean {
    if (isOnEdge(grid, x, y)) {
        return true
    }

    val height = grid[y][x]
    return treeIsVisibleOverRange(grid, 0, x-1, height, y, true) ||  // left
        treeIsVisibleOverRange(grid, x+1, grid[0].size-1, height, y, true) ||  // right
        treeIsVisibleOverRange(grid, 0, y-1, height, x, false) ||  // up
        treeIsVisibleOverRange(grid, y+1, grid.size-1, height, x, false)  // down
}

fun treeIsVisibleOverRange(grid: Grid, start: Int, end: Int, height: Int, staticAxisIndex: Int, checkHorizontal: Boolean): Boolean {
    var i = start
    while (i <= end) {
        val curHeight = if(checkHorizontal) grid[staticAxisIndex][i] else grid[i][staticAxisIndex]
        if (curHeight >= height) {
            return false
        }
        i++
    }

    return numTreesUntilNotVisible(grid, start, end, height, staticAxisIndex, checkHorizontal) == end - start + 1
}

fun scenicScore(grid: Grid, x: Int, y: Int): Int {
    if (isOnEdge(grid, x, y)) {
        return 0
    }

    val height = grid[y][x]
    val temp = numTreesUntilNotVisible(grid, x-1, 0, height, y, true) *  // left
        numTreesUntilNotVisible(grid, x+1, grid[0].size-1, height, y, true) *  // right
        numTreesUntilNotVisible(grid, y-1, 0, height, x, false) *  // up
        numTreesUntilNotVisible(grid, y+1, grid.size-1, height, x, false)  // down
    return temp
}

fun numTreesUntilNotVisible(grid: Grid, start: Int, end: Int, height: Int, staticAxisIndex: Int, checkHorizontal: Boolean): Int {
    val decrementing = end < start
    val shouldContinue: (Int) -> Boolean = { i -> if (decrementing) i >= end else i <= end }
    val numFromStart: (Int) -> Int = { i -> if (decrementing) start - i else i - start }
    
    var i = start
    while (shouldContinue(i)) {
        val curHeight = if(checkHorizontal) grid[staticAxisIndex][i] else grid[i][staticAxisIndex]
        if (curHeight >= height) {
            return numFromStart(i) + 1
        }
        if (decrementing) i-- else i++
    }

    return numFromStart(i)  // don't need to add 1 since i gets inc/dec an extra time when exiting the loop
}

fun isOnEdge(grid: Grid, x: Int, y: Int): Boolean {
    if (x == 0 || x == grid[0].size-1) {
        return true
    }
    if (y == 0 || y == grid.size-1) {
        return true
    }
    return false
}

fun readInput(filepath: String): Grid {
    val grid = mutableListOf<Array<Int>>()

    File(filepath).bufferedReader().forEachLine {
        grid.add(it.map { it.digitToInt() }.toTypedArray())
    }

    return grid.toTypedArray()
}

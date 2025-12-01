import java.io.BufferedReader
import java.io.File

fun main() {
    val root = readInput("../input.txt")
    println("Part 1: " + findSumWithUnderSize(root, 100_000))

    val rootSize = root.calcSize()
    val currentSpace = 70_000_000 - rootSize
    val minToDelete = 30_000_000 - currentSpace
    println("Part 2: " + findDirToDelete(root, minToDelete, Int.MAX_VALUE))
}

fun findSumWithUnderSize(n: Node, maxSize: Int): Int {
    var sum_ = 0

    if (!n.isDir()) {
        return 0
    }

    val nSize = n.calcSize()
    if (nSize <= maxSize) {
        sum_ += nSize
    }
    for (c in n.children) {
        sum_ += findSumWithUnderSize(c, maxSize)
    }
    return sum_
}

fun findDirToDelete(n: Node, neededSpace: Int, min: Int): Int {
    val nSize = n.calcSize()

    var newMin = min
    if (nSize >= neededSpace && nSize < min) {
        newMin = nSize    
    }

    for (c in n.children) {
        newMin = findDirToDelete(c, neededSpace, newMin)
    }
    

    return newMin
}

class Node {
    val name: String
    var size: Int
    var parent: Node? = null
    val children: MutableList<Node>


    constructor(name: String) {
        this.name = name
        this.size = 0
        this.children = mutableListOf()
    }

    constructor(name: String, vararg children: Node) {
        this.name = name
        this.size = 0
        this.children = mutableListOf(*children)
    }

    constructor(name: String, size: Int) {
        this.name = name
        this.size = size
        this.children = mutableListOf()
    }

    fun calcSize(): Int {
        if (children.size == 0) {
            return size
        }

        var fullSize = 0

        for (c in children) {
            fullSize += c.calcSize()
        }

        return fullSize
    }

    fun getChild(name: String): Node {
        for (c in children) {
            if (c.name == name) {
                return c
            }
        }

        throw Exception("Node not found")
    }

    fun addChild(n: Node) {
        this.children.add(n)
    }

    fun isDir(): Boolean {
        return this.children.size > 0
    }
}

fun readInput(filepath: String): Node {
    var root = Node("/")
    var curNode: Node = root

    val reader = File(filepath).bufferedReader()

    var line: String = ""
    var lineFromLS: Boolean = false
    
    while (true) {
        if (!lineFromLS) {
            line = reader.readLine() ?: break
        } else {
            lineFromLS = false
        }

        if (line.startsWith("$")) {
            val split = line.split(" ")
            val command = split[1]

            when (command) {
                "cd" -> {
                    curNode = handleCD(split[2], root, curNode)
                }
                "ls" -> {
                    val nextCommand = handleLS(reader, curNode)
                    if (nextCommand != null) {
                        line = nextCommand
                        lineFromLS = true
                    }
                }
            }
        } 
    }

    return root
}

fun handleCD(path: String, root: Node, curNode: Node): Node {
    return when (path) {
        "/" -> root
        ".." -> curNode.parent!!
        else -> curNode.getChild(path)
    }
}

fun handleLS(reader: BufferedReader, curNode: Node): String? {
    while (true) {
        val line = reader.readLine() ?: break

        if (line.startsWith("$")) {
            return line
        }

        val split = line.split(" ")
        val newNode = Node(split[1])
        newNode.parent = curNode
        if (split[0] != "dir") {
            newNode.size = split[0].toInt()
        } 
        curNode.addChild(newNode)
    }

    return null
}

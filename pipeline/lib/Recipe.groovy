package utils  // optional but tidy

class Recipe {
  private static List<String> csvSplit(String s) {
    s.split(/,(?=(?:[^"]*"[^"]*")*[^"]*$)/, -1) as List<String>
  }
  static Map load(java.nio.file.Path path) {
    def lines = java.nio.file.Files.readAllLines(path)
    if (!lines || lines.size() < 2) return [:]
    def map = [:]
    lines.drop(1).each { line ->
      if (!line?.trim()) return
      def cols = csvSplit(line)
      def t = cols[0]?.trim()
      def e = (cols.size() > 1 ? cols[1] : "")?.trim()?.replaceAll(/^"(.*)"$/, '$1')
      if (t) map[t] = e
    }
    map
  }
  static String basename(String p) {
    if (!p) return null
    p.replaceAll('/+$','').tokenize('/').last()
  }
}

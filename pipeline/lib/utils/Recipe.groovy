package utils  // optional but tidy

class Recipe {
  private static List<String> csvSplit(String s) {
    s.split(/,(?=(?:[^"]*"[^"]*")*[^"]*$)/, -1) as List<String>
  }
  static Map load(java.nio.file.Path path) {
    def lines = java.nio.file.Files.readAllLines(path)
    if (!lines || lines.size() < 2) return [:]        // conditional check
    def map = [:]                                     // map is a dictionary
    lines.drop(1).each { line ->                      // skip the header and iterate over the remaining lines
      if (!line?.trim()) return                       // skips empty lines
      def cols = csvSplit(line)                       // for line "abc,def,xyz" we get ["abc", "def", "xyz"]
      def t = cols[0]?.trim()                         // cols[0] (first column) becomes the key
      def e = (cols.size() > 1 ? cols[1] : "")?.trim()?.replaceAll(/^"(.*)"$/, '$1')    // handles second column for emptyness, removes any leading/trailing white space, strips surrounding quotes (usefull if you want to split the string (no bad quotas))
      if (t) map[t] = e                               // assigns value to the key recipe["type"] = "entry"
    }
    map
  }
}

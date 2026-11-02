import Foundation
let path = CommandLine.arguments[1]
let data = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
let map: [Character: FastLevel] = ["S": .strict, "W": .wineOil, "F": .fish, "D": .dairy, "N": .noFast]
var total = 0, ok = 0
var misses: [String] = []
let wdn = ["", "Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]
for (k, v) in data.sorted(by: { $0.key < $1.key }) where !k.hasPrefix("_") {
    let parts = k.split(separator: "-"); let y = Int(parts[0])!, m = Int(parts[1])!
    for (i, ch) in (v as! String).enumerated() {
        let d = CivilDate(year: y, month: m, day: i + 1)
        var got = FastingRules.fasting(civil: d, calendar: .newCalendar).level
        if got == .fastFree { got = .noFast }
        let exp = map[ch]!
        total += 1
        if got == exp { ok += 1 } else {
            let f = FastingRules.fasting(civil: d, calendar: .newCalendar)
            misses.append("\(d.monthDayKey) \(y) \(wdn[d.weekday]) pd=\(Paschalion.distance(from: d)) exp=\(exp) got=\(got) [\(f.season)]")
        }
    }
}
print("OK \(ok)/\(total)")
misses.forEach { print($0) }

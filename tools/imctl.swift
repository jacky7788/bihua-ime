import Carbon
import Foundation
func sid(_ s: TISInputSource?) -> String {
    guard let s = s, let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) else { return "?" }
    return "\(Unmanaged<CFTypeRef>.fromOpaque(p).takeUnretainedValue())"
}
let args = CommandLine.arguments
if args.count < 2 || args[1] == "--get" {
    print(sid(TISCopyCurrentKeyboardInputSource()?.takeRetainedValue())); exit(0)
}
let want = args[1]
for all in [false, true] {
    let list = TISCreateInputSourceList(nil, all)?.takeRetainedValue() as? [TISInputSource] ?? []
    if let s = list.first(where: { sid($0) == want }) {
        let r = TISSelectInputSource(s)
        print("select \(want) (all=\(all)) -> \(r)")
        exit(r == 0 ? 0 : 1)
    }
}
print("not found: \(want)"); exit(1)

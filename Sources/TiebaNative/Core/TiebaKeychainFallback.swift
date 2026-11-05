// Keychain 缺权限（errSecMissingEntitlement = -34018）时的兜底存储：TrollStore、部分重签
// 工具签出的包不带 keychain 相关 entitlement，SecItem* 全部失败、登录凭据写不进去。
// 此时改存沙盒内的受数据保护文件（首次解锁后可读，与 Keychain 档位一致；不进备份）。
import Foundation
import Security

enum TiebaKeychainFallback {
  private static let fileName = "tiebalite.keychain-fallback.plist"
  private static let entries = TiebaMutex<[String: Data]?>(nil)

  static func get(_ key: String) -> Data? {
    entries.withLock { loaded(&$0)[key] }
  }

  static func keys(prefix: String) -> [String] {
    entries.withLock { loaded(&$0).keys.filter { $0.hasPrefix(prefix) } }
  }

  static func set(_ key: String, _ value: Data) throws {
    try entries.withLock { state in
      var next = loaded(&state)
      next[key] = value
      try write(next)
      state = next
    }
  }

  static func delete(_ key: String) {
    entries.withLock { state in
      var next = loaded(&state)
      guard next.removeValue(forKey: key) != nil else { return }
      try? write(next)
      state = next
    }
  }

  private static func loaded(_ state: inout [String: Data]?) -> [String: Data] {
    if let state { return state }
    var result: [String: Data] = [:]
    if let url = fileURL(),
      let data = try? Data(contentsOf: url),
      let decoded = try? PropertyListDecoder().decode([String: Data].self, from: data)
    {
      result = decoded
    }
    state = result
    return result
  }

  private static func fileURL() -> URL? {
    try? FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent(fileName)
  }

  private static func write(_ entries: [String: Data]) throws {
    guard var url = fileURL() else { throw TiebaKeychainError.writeFailed(errSecMissingEntitlement) }
    let data = try PropertyListEncoder().encode(entries)
    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
  }
}

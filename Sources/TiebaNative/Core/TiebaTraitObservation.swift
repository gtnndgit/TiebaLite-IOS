import UIKit

/// `registerForTraitChanges` 的跨版本替身：iOS 17+ 直接转调系统 API；
/// iOS 16 挂一个隐藏探针子视图，靠它的 `traitCollectionDidChange` 回调。
enum TiebaTrait {
  case userInterfaceStyle
  case accessibilityContrast
  case preferredContentSizeCategory
  case horizontalSizeClass

  @available(iOS 17.0, *)
  var uiTrait: UITrait {
    switch self {
    case .userInterfaceStyle: return UITraitUserInterfaceStyle.self
    case .accessibilityContrast: return UITraitAccessibilityContrast.self
    case .preferredContentSizeCategory: return UITraitPreferredContentSizeCategory.self
    case .horizontalSizeClass: return UITraitHorizontalSizeClass.self
    }
  }

  @MainActor
  func differs(_ old: UITraitCollection, _ new: UITraitCollection) -> Bool {
    switch self {
    case .userInterfaceStyle: return old.userInterfaceStyle != new.userInterfaceStyle
    case .accessibilityContrast: return old.accessibilityContrast != new.accessibilityContrast
    case .preferredContentSizeCategory:
      return old.preferredContentSizeCategory != new.preferredContentSizeCategory
    case .horizontalSizeClass: return old.horizontalSizeClass != new.horizontalSizeClass
    }
  }
}

/// 登记令牌：与系统 API 一样，不持有也会随宿主对象存活。
final class TiebaTraitRegistration {
  fileprivate let token: Any

  fileprivate init(_ token: Any) {
    self.token = token
  }
}

private final class TiebaTraitProbeView: UIView {
  private let traits: [TiebaTrait]
  private let onChange: (UITraitCollection) -> Void

  init(traits: [TiebaTrait], onChange: @escaping (UITraitCollection) -> Void) {
    self.traits = traits
    self.onChange = onChange
    super.init(frame: .zero)
    isHidden = true
    isUserInteractionEnabled = false
    isAccessibilityElement = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard let previousTraitCollection,
      traits.contains(where: { $0.differs(previousTraitCollection, traitCollection) })
    else { return }
    onChange(previousTraitCollection)
  }
}

@MainActor
private func tiebaInstallTraitProbe<T>(
  on host: UIView,
  owner: AnyObject,
  traits: [TiebaTrait],
  handler: @escaping (T, UITraitCollection) -> Void
) -> TiebaTraitRegistration {
  let probe = TiebaTraitProbeView(traits: traits) { [weak owner] previous in
    guard let target = owner as? T else { return }
    handler(target, previous)
  }
  host.addSubview(probe)
  return TiebaTraitRegistration(probe)
}

extension UIView {
  @discardableResult
  func observeTraits<T: UITraitEnvironment>(
    _ traits: [TiebaTrait],
    handler: @escaping (T, UITraitCollection) -> Void
  ) -> TiebaTraitRegistration {
    if #available(iOS 17.0, *) {
      return TiebaTraitRegistration(
        registerForTraitChanges(traits.map(\.uiTrait), handler: handler))
    }
    return tiebaInstallTraitProbe(on: self, owner: self, traits: traits, handler: handler)
  }
}

extension UIViewController {
  @discardableResult
  func observeTraits<T: UITraitEnvironment>(
    _ traits: [TiebaTrait],
    handler: @escaping (T, UITraitCollection) -> Void
  ) -> TiebaTraitRegistration {
    if #available(iOS 17.0, *) {
      return TiebaTraitRegistration(
        registerForTraitChanges(traits.map(\.uiTrait), handler: handler))
    }
    return tiebaInstallTraitProbe(on: view, owner: self, traits: traits, handler: handler)
  }
}

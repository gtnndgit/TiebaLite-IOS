import UIKit

/// `UIContentUnavailableConfiguration` 的跨版本替身（只含本仓用到的成员）。
/// iOS 17+ 由 `TiebaUnavailableView` 转成系统配置交给系统视图排版；iOS 16 自绘。
@MainActor
struct TiebaUnavailableConfiguration {
  struct ImageProperties {
    var tintColor: UIColor?
    var maximumSize: CGSize = .zero
  }

  struct TextProperties {
    var font: UIFont?
    var color: UIColor?
  }

  struct ButtonProperties {
    var primaryAction: UIAction?
  }

  fileprivate var isLoading = false
  var image: UIImage?
  var text: String?
  var secondaryText: String?
  var button: UIButton.Configuration?
  var buttonProperties = ButtonProperties()
  var imageProperties = ImageProperties()
  var textProperties = TextProperties()
  var secondaryTextProperties = TextProperties()

  static func empty() -> TiebaUnavailableConfiguration {
    TiebaUnavailableConfiguration()
  }

  static func loading() -> TiebaUnavailableConfiguration {
    var config = TiebaUnavailableConfiguration()
    config.isLoading = true
    return config
  }

  @available(iOS 17.0, *)
  fileprivate func systemConfiguration() -> UIContentUnavailableConfiguration {
    var config: UIContentUnavailableConfiguration = isLoading ? .loading() : .empty()
    if let image { config.image = image }
    if let text { config.text = text }
    if let secondaryText { config.secondaryText = secondaryText }
    if let button { config.button = button }
    config.buttonProperties.primaryAction = buttonProperties.primaryAction
    if let tint = imageProperties.tintColor { config.imageProperties.tintColor = tint }
    config.imageProperties.maximumSize = imageProperties.maximumSize
    if let font = textProperties.font { config.textProperties.font = font }
    if let color = textProperties.color { config.textProperties.color = color }
    if let font = secondaryTextProperties.font { config.secondaryTextProperties.font = font }
    if let color = secondaryTextProperties.color { config.secondaryTextProperties.color = color }
    return config
  }
}

/// `UIContentUnavailableView` 的跨版本替身。
final class TiebaUnavailableView: UIView {
  var configuration: TiebaUnavailableConfiguration {
    didSet { apply() }
  }

  private var systemView: UIView?
  private let stack = UIStackView()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let imageView = UIImageView()
  private let textLabel = UILabel()
  private let secondaryLabel = UILabel()
  private var button: UIButton?
  private var imageMaxWidth: NSLayoutConstraint?
  private var imageMaxHeight: NSLayoutConstraint?
  private var lastFittingWidth: CGFloat = 0

  init(configuration: TiebaUnavailableConfiguration) {
    self.configuration = configuration
    super.init(frame: .zero)
    if #available(iOS 17.0, *) {
      let view = UIContentUnavailableView(configuration: configuration.systemConfiguration())
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
      NSLayoutConstraint.activate([
        view.leadingAnchor.constraint(equalTo: leadingAnchor),
        view.trailingAnchor.constraint(equalTo: trailingAnchor),
        view.topAnchor.constraint(equalTo: topAnchor),
        view.bottomAnchor.constraint(equalTo: bottomAnchor),
      ])
      systemView = view
    } else {
      setUpFallback()
    }
    apply()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override var intrinsicContentSize: CGSize {
    if systemView != nil { return super.intrinsicContentSize }
    let margins = directionalLayoutMargins
    let width = (bounds.width > 0 ? bounds.width : 320) - margins.leading - margins.trailing
    let fitting = stack.systemLayoutSizeFitting(
      CGSize(width: max(width, 1), height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    return CGSize(
      width: UIView.noIntrinsicMetric, height: fitting.height + margins.top + margins.bottom)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard systemView == nil, bounds.width != lastFittingWidth else { return }
    lastFittingWidth = bounds.width
    invalidateIntrinsicContentSize()
  }

  private func setUpFallback() {
    directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 0
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .secondaryLabel
    imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .largeTitle)
    imageView.setContentCompressionResistancePriority(.required, for: .vertical)

    for label in [textLabel, secondaryLabel] {
      label.numberOfLines = 0
      label.textAlignment = .center
      label.adjustsFontForContentSizeCategory = true
    }

    spinner.hidesWhenStopped = true
    [spinner, imageView, textLabel, secondaryLabel].forEach(stack.addArrangedSubview)
    stack.setCustomSpacing(12, after: spinner)
    stack.setCustomSpacing(12, after: imageView)
    stack.setCustomSpacing(6, after: textLabel)
    stack.setCustomSpacing(16, after: secondaryLabel)

    let guide = layoutMarginsGuide
    let maxWidth = stack.widthAnchor.constraint(lessThanOrEqualToConstant: 480)
    let centerY = stack.centerYAnchor.constraint(equalTo: guide.centerYAnchor)
    centerY.priority = .defaultHigh
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
      centerY,
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor),
      stack.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor),
      maxWidth,
    ])
  }

  private func apply() {
    if #available(iOS 17.0, *), let view = systemView as? UIContentUnavailableView {
      view.configuration = configuration.systemConfiguration()
      return
    }
    let config = configuration

    if config.isLoading {
      spinner.startAnimating()
    } else {
      spinner.stopAnimating()
    }

    imageView.image = config.image
    imageView.isHidden = config.image == nil
    imageView.tintColor = config.imageProperties.tintColor ?? .secondaryLabel
    imageMaxWidth?.isActive = false
    imageMaxHeight?.isActive = false
    let maxSize = config.imageProperties.maximumSize
    if maxSize.width > 0 {
      imageMaxWidth = imageView.widthAnchor.constraint(lessThanOrEqualToConstant: maxSize.width)
      imageMaxWidth?.isActive = true
    }
    if maxSize.height > 0 {
      imageMaxHeight = imageView.heightAnchor.constraint(lessThanOrEqualToConstant: maxSize.height)
      imageMaxHeight?.isActive = true
    }

    let loadingText = config.isLoading && config.text == nil ? "加载中…" : nil
    textLabel.text = config.text ?? loadingText
    textLabel.isHidden = textLabel.text?.isEmpty ?? true
    textLabel.font =
      config.textProperties.font
      ?? (loadingText != nil
        ? .preferredFont(forTextStyle: .body)
        : UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20, weight: .semibold)))
    textLabel.textColor =
      config.textProperties.color ?? (loadingText != nil ? .secondaryLabel : .label)

    secondaryLabel.text = config.secondaryText
    secondaryLabel.isHidden = config.secondaryText?.isEmpty ?? true
    secondaryLabel.font = config.secondaryTextProperties.font ?? .preferredFont(forTextStyle: .body)
    secondaryLabel.textColor = config.secondaryTextProperties.color ?? .secondaryLabel

    button?.removeFromSuperview()
    button = nil
    if let buttonConfig = config.button {
      let newButton = UIButton(configuration: buttonConfig, primaryAction: config.buttonProperties.primaryAction)
      stack.addArrangedSubview(newButton)
      button = newButton
    }

    invalidateIntrinsicContentSize()
  }
}

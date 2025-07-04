import AppKit
import Combine
import InlineKit
import Logger

class SidebarSenderView: NSStackView {
  private var userInfo: UserInfo

  // MARK: - UI props

  static let avatarSize: CGFloat = 12
  static let height: CGFloat = 15

  var user: User {
    userInfo.user
  }

  var inlineWithMessage: Bool = false

  init(userInfo: UserInfo) {
    self.userInfo = userInfo
    super.init(frame: .zero)
    setup()
  }

  private func setup() {
    orientation = .horizontal
    spacing = 1
    edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    alignment = .centerY
    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = false

    NSLayoutConstraint.activate([
      avatarView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
      avatarView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

      heightAnchor.constraint(equalToConstant: Self.height),
    ])

    addArrangedSubview(avatarView)
    addArrangedSubview(nameLabel)
    configure(with: userInfo, inlineWithMessage: inlineWithMessage)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The avatar view
  lazy var avatarView: UserAvatarView = {
    let view = UserAvatarView(
      userInfo: userInfo,
      size: Self.avatarSize
    )
    view.translatesAutoresizingMaskIntoConstraints = false
    view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    return view
  }()

  /// The title label
  lazy var nameLabel: NSTextField = {
    let view = NSTextField()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isEditable = false
    view.isBordered = false
    view.clipsToBounds = false
    view.backgroundColor = .clear
    view.font = .systemFont(ofSize: 13, weight: .regular)
    view.alphaValue = 0.8
    view.textColor = .secondaryLabelColor
    view.lineBreakMode = .byTruncatingTail
    view.maximumNumberOfLines = 1
    view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    view.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return view
  }()

  /// The sender view

  func configure(with userInfo: UserInfo, inlineWithMessage: Bool) {
    self.userInfo = userInfo
    self.inlineWithMessage = inlineWithMessage

    // Update avatar
    avatarView.removeFromSuperview()
    avatarView = UserAvatarView(
      userInfo: userInfo,
      size: Self.avatarSize
    )
    avatarView.translatesAutoresizingMaskIntoConstraints = false
    insertArrangedSubview(avatarView, at: 0)

    // Update name
    nameLabel.stringValue = user.firstName ??
      user.lastName ??
      user.username ??
      user.phoneNumber ??
      user.email ?? ""

    if inlineWithMessage {
      nameLabel.stringValue += ":"
    }
  }
}

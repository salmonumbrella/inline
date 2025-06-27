// MessageView.swift
import AppKit
import Auth
import Combine
import Foundation
import GRDB
import InlineKit
import InlineUI
import Logger
import Nuke
import NukeUI
import SwiftUI
import TextProcessing
import Throttler

class MessageViewAppKit: NSView {
  private let feature_relayoutOnBoundsChange = true
  private let log = Log.scoped("MessageView", enableTracing: false)
  static let avatarSize: CGFloat = Theme.messageAvatarSize
  private(set) var fullMessage: FullMessage
  private var props: MessageViewProps
  private var shineEffectView: ShineEffectView?
  private var translationStateCancellable: AnyCancellable?
  private var from: User {
    fullMessage.from ?? User.deletedInstance
  }

  private var message: Message {
    fullMessage.message
  }

  private var isDM: Bool {
    props.isDM
  }

  private var chatHasAvatar: Bool {
    !isDM
  }

  private var showsAvatar: Bool {
    chatHasAvatar && props.layout.hasAvatar && !outgoing
  }

  private var showsName: Bool {
    chatHasAvatar && props.layout.hasName
  }

  private var hasReactions: Bool {
    props.layout.hasReactions
  }

  private var outgoing: Bool {
    message.out == true
  }

  private var hasLegacyPhoto: Bool {
    if let file = fullMessage.file, file.fileType == .photo {
      return true
    }
    return false
  }

  private var hasPhoto: Bool {
    props.layout.hasPhoto
  }

  private var hasVideo: Bool {
    false
  }

  private var hasDocument: Bool {
    props.layout.hasDocument
  }

  private var hasReply: Bool {
    props.layout.hasReply
  }

  private var hasText: Bool {
    props.layout.hasText
  }

  private var textWidth: CGFloat {
    props.layout.text?.size.width ?? 1.0
  }

  private var contentWidth: CGFloat {
    props.layout.bubble.size.width
  }

  private var textColor: NSColor {
    if outgoing {
      NSColor.white
    } else {
      NSColor.labelColor
    }
  }

  private var bubbleBackgroundColor: NSColor {
    if fullMessage.message.isSticker == true {
      NSColor.clear
    } else if outgoing {
      Theme.messageBubblePrimaryBgColor
    } else {
      Theme.messageBubbleSecondaryBgColor
    }
  }

  private var linkColor: NSColor {
    if outgoing {
      NSColor.white
    } else {
      NSColor.linkColor
    }
  }

  private var mentionColor: NSColor {
    if outgoing {
      NSColor.white
    } else {
      NSColor.systemBlue
    }
  }

  private var senderFont: NSFont {
    .systemFont(
      ofSize: 12,
      weight: .semibold
    )
  }

  // State
  private var isMouseInside = false

  // Add gesture recognizer property
  private var longPressGesture: NSPressGestureRecognizer?
  private var doubleClickGesture: NSClickGestureRecognizer?
  private var avatarClickGesture: NSClickGestureRecognizer?

  // MARK: Views

  private lazy var bubbleView: BasicView = {
    let view = BasicView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.cornerRadius = Theme.messageBubbleCornerRadius
    view.backgroundColor = bubbleBackgroundColor
    return view
  }()

  private lazy var avatarView: UserAvatarView = {
    let view = UserAvatarView(userInfo: fullMessage.senderInfo ?? .deleted)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var nameLabel: NSTextField = {
    let label = NSTextField(labelWithString: "")
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = senderFont
    label.lineBreakMode = .byTruncatingTail

    return label
  }()

  private lazy var contentView: NSView = {
    let view = NSView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var timeAndStateView: MessageTimeAndState = {
    let view = MessageTimeAndState(fullMessage: fullMessage)
    view.translatesAutoresizingMaskIntoConstraints = false
    view.wantsLayer = true
    return view
  }()

  private lazy var newPhotoView: NewPhotoView = {
    let view = NewPhotoView(fullMessage, scrollState: scrollState)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var documentView: DocumentView? = {
    guard let documentInfo = fullMessage.documentInfo else { return nil }

    let view = DocumentView(
      documentInfo: documentInfo,
      fullMessage: self.fullMessage,
      white: outgoing
    )
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var replyView: EmbeddedMessageView = {
    let view = EmbeddedMessageView(style: outgoing ? .white : .colored)
    view.translatesAutoresizingMaskIntoConstraints = false
    if let embeddedMessage = fullMessage.repliedToMessage {
      view.update(with: embeddedMessage, kind: .replyInMessage)
    }
    return view
  }()

  private var useTextKit2: Bool = true

  private var prevDelegate: NSTextViewportLayoutControllerDelegate?

  private lazy var textView: NSTextView = {
    if useTextKit2 {
      let textView = MessageTextView(usingTextLayoutManager: true)
      textView.translatesAutoresizingMaskIntoConstraints = false
      textView.isEditable = false
      textView.isSelectable = true
      textView.backgroundColor = .clear
      textView.drawsBackground = false
      // Clips to bounds = false fucks up performance so badly. what!?
      // textView.clipsToBounds = true
      textView.textContainerInset = MessageTextConfiguration.containerInset
      textView.font = MessageTextConfiguration.font
      textView.textColor = textColor
      textView.wantsLayer = true
      textView.layerContentsRedrawPolicy = .onSetNeedsDisplay
      textView.layer?.drawsAsynchronously = true
      textView.layer?.needsDisplayOnBoundsChange = true

      let textContainer = textView.textContainer
      textContainer?.widthTracksTextView = false
      textContainer?.heightTracksTextView = false

      // Configure basic text view behavior
      textView.allowsImageEditing = false
      textView.isGrammarCheckingEnabled = false
      textView.isContinuousSpellCheckingEnabled = false
      textView.isAutomaticQuoteSubstitutionEnabled = false
      textView.isAutomaticDashSubstitutionEnabled = false
      textView.isAutomaticTextReplacementEnabled = false

      textView.isVerticallyResizable = false
      textView.isHorizontallyResizable = false
      textView.delegate = self

      // we need default delegate to handle rendering (GENIUS)
      prevDelegate = textView.textLayoutManager?.textViewportLayoutController.delegate
      textView.textLayoutManager?.textViewportLayoutController.delegate = self

      // In NSTextView you need to customize link colors here otherwise the attributed string for links
      // does not have any effect.
      textView.linkTextAttributes = [
        .foregroundColor: linkColor,
        // .underlineStyle: NSUnderlineStyle.single.rawValue,
        .cursor: NSCursor.pointingHand,
      ]

      // Match the sizes and spacing with the size calculator we use to calculate cell height
      MessageTextConfiguration.configureTextContainer(textContainer!)
      MessageTextConfiguration.configureTextView(textView)

      return textView
    } else {
      let textContainer = NSTextContainer(size: props.layout.text?.size ?? .zero)
      let layoutManager = NSLayoutManager()
      let textStorage = NSTextStorage()

      textStorage.addLayoutManager(layoutManager)
      layoutManager.addTextContainer(textContainer)

      let textView = MessageTextView(frame: .zero, textContainer: textContainer)

      // Essential TextKit 1 optimizations
      textContainer.lineFragmentPadding = 0
      textContainer.maximumNumberOfLines = 0
      textContainer.widthTracksTextView = false
      textContainer.heightTracksTextView = false
      textContainer.lineBreakMode = .byClipping
      textContainer.maximumNumberOfLines = 0
      textContainer.containerSize = props.layout.text?.size ?? .zero
      textContainer.size = props.layout.text?.size ?? .zero

      //    layoutManager.showsControlCharacters = true
      //    layoutManager.showsInvisibleCharacters = true

      layoutManager.usesDefaultHyphenation = false
      layoutManager.allowsNonContiguousLayout = true
      layoutManager.backgroundLayoutEnabled = true

      // Match your existing configuration
      textView.isEditable = false
      textView.isSelectable = true
      textView.usesFontPanel = false
      textView.textContainerInset = MessageTextConfiguration.containerInset
      textView.linkTextAttributes = [
        .foregroundColor: linkColor,
        .underlineStyle: NSUnderlineStyle.single.rawValue,
        .cursor: NSCursor.pointingHand,
      ]
      textView.delegate = self
      textView.wantsLayer = true
      textView.layer?.drawsAsynchronously = true
      textView.layerContentsRedrawPolicy = .onSetNeedsDisplay
      textView.layer?.contentsGravity = .topLeft
      textView.layer?.needsDisplayOnBoundsChange = true
      textView.drawsBackground = false
      textView.isVerticallyResizable = false
      textView.isHorizontallyResizable = false
      textView.translatesAutoresizingMaskIntoConstraints = false
      return textView
    }
  }()

  private var reactionsViewModel: ReactionsViewModel?
  private var reactionsView: NSView?

  // MARK: - Initialization

  init(fullMessage: FullMessage, props: MessageViewProps, isScrolling: Bool = false) {
    self.fullMessage = fullMessage
    self.props = props
    scrollState = isScrolling ? .scrolling : .idle
    super.init(frame: .zero)
    setupView()

    DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
      self?.setupScrollStateObserver()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func layout() {
    super.layout()
  }

  // MARK: - Setup

  deinit {
    NotificationCenter.default.removeObserver(self)
    if let observer = notificationObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    translationStateCancellable?.cancel()
  }

  private func setupView() {
    // For performance of animations
    wantsLayer = true
    layerContentsRedrawPolicy = .onSetNeedsDisplay
    layer?.drawsAsynchronously = true

    addSubview(bubbleView)

    if showsAvatar {
      addSubview(avatarView)
    }

    if showsName {
      addSubview(nameLabel)
      let name = from.firstName ?? from.username ?? ""
      let nameForInitials = UserAvatar.getNameForInitials(user: from)
      nameLabel.stringValue = outgoing ? "You" : name
      nameLabel.textColor = NSColor(
        InitialsCircle.ColorPalette
          .color(for: nameForInitials)
      )
    }

    addSubview(contentView)

    if hasReply {
      contentView.addSubview(replyView)
    }

    if hasPhoto {
      contentView.addSubview(newPhotoView)
    }

    if hasDocument, let documentView {
      contentView.addSubview(documentView)
    }

    if hasText {
      contentView.addSubview(textView)
    }

    if hasReactions {
      setupReactions()
    }

    addSubview(timeAndStateView)

    setupMessageText()
    setupContextMenu()
    setupGestureRecognizers()

    // Setup translation state observation
    setupTranslationStateObservation()
  }

  private func setupTranslationStateObservation() {
    translationStateCancellable = TranslatingStatePublisher.shared.publisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] translatingSet in
        guard let self else { return }
        let isTranslating = translatingSet.contains(
          TranslatingStatePublisher.TranslatingStateHolder.Translating(
            messageId: message.messageId,
            peerId: message.peerId
          )
        )
        updateShineEffect(isTranslating: isTranslating)
      }
  }

  private func updateShineEffect(isTranslating: Bool) {
    if isTranslating {
      if shineEffectView == nil {
        let shineView = ShineEffectView(frame: bubbleView.bounds)
        shineView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(shineView)

        NSLayoutConstraint.activate([
          shineView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
          shineView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
          shineView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
          shineView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
        ])

        shineEffectView = shineView
        shineView.startAnimation()
      }
    } else {
      shineEffectView?.stopAnimation()
      shineEffectView?.removeFromSuperview()
      shineEffectView = nil
    }
  }

  // MARK: - Reactions UI

  private func setupReactions() {
    // View model
    reactionsViewModel = ReactionsViewModel(
      reactions: fullMessage.groupedReactions,
      offsets: props.layout.reactionItems,
      fullMessage: fullMessage,
      width: props.layout.reactions?.size.width ?? 0,
      height: props.layout.reactions?.size.height ?? 0,
    )

    if let oldView = reactionsView {
      oldView.removeFromSuperview()
    }

    // View
    let view = NSHostingView<ReactionsView>(rootView: ReactionsView(viewModel: reactionsViewModel!))
    view.translatesAutoresizingMaskIntoConstraints = false
    reactionsView = view

    // debug
//    let view = NSView()
//    view.translatesAutoresizingMaskIntoConstraints = false
//    view.wantsLayer = true
//    view.layer?.backgroundColor = NSColor.red.cgColor
//    reactionsView = view

    contentView.addSubview(reactionsView!)

    // Reactions
    if let reactionsPlan = props.layout.reactions, let reactionsView {
      reactionViewHeightConstraint = reactionsView.heightAnchor.constraint(
        equalToConstant: reactionsPlan.size.height
      )
      reactionViewWidthConstraint = reactionsView.widthAnchor.constraint(
        equalToConstant: reactionsPlan.size.width
      )
      reactionViewTopConstraint = reactionsView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: props.layout.reactionsViewTop
      )

      NSLayoutConstraint.activate(
        [
          reactionViewHeightConstraint,
          reactionViewWidthConstraint,
          reactionViewTopConstraint,
          reactionsView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: reactionsPlan.spacing.left
          ),
        ]
      )
    }
  }

  private func updateReactionsSizes() {
    // Update
    reactionsViewModel?.reactions = fullMessage.groupedReactions
    reactionsViewModel?.offsets = props.layout.reactionItems
    reactionsViewModel?.width = props.layout.reactions?.size.width ?? 0
    reactionsViewModel?.height = props.layout.reactions?.size.height ?? 0
  }

  private func updateReactions(prev: FullMessage, next: FullMessage, props: MessageViewProps) {
    if reactionsView == nil, next.reactions.count > 0 {
      log.trace("Adding reactions view \(props.layout.reactions)")
      // Added
      setupReactions()
      needsUpdateConstraints = true
      layoutSubtreeIfNeeded()
    } else if reactionsView != nil, next.reactions.count == 0 {
      log.trace("Removing reactions view")
      // Remove
      reactionsView?.removeFromSuperview()
      reactionsView = nil
    } else {
      log.trace("Updating reactions view")
      // Update
      reactionsViewModel?.width = props.layout.reactions?.size.width ?? 0
      reactionsViewModel?.height = props.layout.reactions?.size.height ?? 0
      reactionsViewModel?.offsets = props.layout.reactionItems
      reactionsViewModel?.reactions = next.groupedReactions
      reactionsViewModel?.fullMessage = next
    }
  }

  private func setupGestureRecognizers() {
    // Add long press gesture recognizer
    longPressGesture = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    longPressGesture?.minimumPressDuration = 0.5
    longPressGesture?.allowableMovement = 10
    if let gesture = longPressGesture {
      addGestureRecognizer(gesture)
    }

    // Add double click gesture recognizer
    doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
    doubleClickGesture?.numberOfClicksRequired = 2
    doubleClickGesture?.delaysPrimaryMouseButtonEvents = false
    if let gesture = doubleClickGesture {
      addGestureRecognizer(gesture)
    }

    if showsAvatar {
      avatarClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleAvatarClick(_:)))
      if let gesture = avatarClickGesture {
        avatarView.addGestureRecognizer(gesture)
      }
    }
  }

  @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
    if gesture.state == .began {
      // Provide haptic feedback
      NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)

      // Show reaction overlay
      showReactionOverlay()
    }
  }

  @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
    // Check if click is within text view bounds
    let location = gesture.location(in: self)
    if hasText, let textViewFrame = textView.superview?.convert(textView.frame, to: self),
       textViewFrame.contains(location)
    {
      return // Ignore double click if it's on the text
    }

    // Provide haptic feedback
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)

    guard let currentUserId = Auth.shared.currentUserId else { return }
    let weReacted = fullMessage.groupedReactions.contains { reaction in
      reaction.reactions.contains { fullReaction in
        fullReaction.reaction.userId == currentUserId
      }
    }

    let emoji = "✔️"

    // Set reaction
    if weReacted {
      // Remove reaction
      Transactions.shared.mutate(transaction: .deleteReaction(.init(
        message: fullMessage.message,
        emoji: emoji,
        peerId: fullMessage.message.peerId,
        chatId: fullMessage.message.chatId
      )))
    } else {
      // Add reaction
      Transactions.shared.mutate(transaction: .addReaction(.init(
        message: fullMessage.message,
        emoji: emoji,
        userId: currentUserId,
        peerId: fullMessage.message.peerId
      )))
    }
  }

  @objc private func handleAvatarClick(_ gesture: NSClickGestureRecognizer) {
    guard !isDM else { return }
    guard let user = fullMessage.senderInfo?.user else { return }

    Task { @MainActor in
      do {
        let _ = try await DataManager.shared.createPrivateChat(userId: user.id)
        Nav.main.open(.chat(peer: .user(id: user.id)))
      } catch {
        Log.shared.error("Failed to open a private chat with \(user.anyName)", error: error)
      }
    }
  }

  private func setupConstraints() {
    var constraints: [NSLayoutConstraint] = []
    let layout = props.layout

    defer {
      NSLayoutConstraint.activate(constraints)
    }

    // Note:
    // There shouldn't be any calculations of sizes or spacing here. All of it must be off-loaded to SizeCalculator
    // and stored in the layout plan.

    // Content View Top and Bottom Insets
//    contentView.edgeInsets = NSEdgeInsets(
//      top: layout.topMostContentTopSpacing,
//      left: 0,
//      bottom: layout.bottomMostContentBottomSpacing,
//      right: 0
//    )

    if let avatar = layout.avatar, showsAvatar {
      constraints.append(
        contentsOf: [
          avatarView.leadingAnchor
            .constraint(equalTo: leadingAnchor, constant: avatar.spacing.left),
          avatarView.topAnchor
            .constraint(
              equalTo: topAnchor,
              constant: avatar.spacing.top + layout.wrapper.spacing.top
            ),
          avatarView.widthAnchor.constraint(equalToConstant: avatar.size.width),
          avatarView.heightAnchor.constraint(equalToConstant: avatar.size.height),
        ]
      )
    }

    if let name = layout.name, showsName {
      constraints.append(
        contentsOf: [
          nameLabel.leadingAnchor
            .constraint(
              equalTo: leadingAnchor,
              constant: layout.nameAndBubbleLeading + name.spacing.left
            ),
          nameLabel.topAnchor
            .constraint(equalTo: topAnchor, constant: layout.wrapper.spacing.top),
          nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
          nameLabel.heightAnchor
            .constraint(equalToConstant: name.size.height),
        ]
      )
    }

    // Bubble And Content View

    if layout.hasName {
      // if we have name, attach bubble to it
      constraints.append(contentsOf: [
        bubbleView.topAnchor.constraint(
          equalTo: nameLabel.bottomAnchor
        ),
        contentView.topAnchor.constraint(
          equalTo: nameLabel.bottomAnchor
        ),
      ])

    } else {
      // otherwise attach to top
      constraints.append(contentsOf: [
        bubbleView.topAnchor.constraint(
          equalTo: topAnchor,
          constant: layout.wrapper.spacing.top
        ),
        contentView.topAnchor.constraint(
          equalTo: topAnchor,
          constant: layout.wrapper.spacing.top
        ),
      ])
    }

    bubbleViewHeightConstraint = bubbleView.heightAnchor.constraint(equalToConstant: layout.bubble.size.height)
    bubbleViewWidthConstraint = bubbleView.widthAnchor.constraint(
      equalToConstant: layout.bubble.size.width
    )
    contentViewWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: layout.bubble.size.width)
    contentViewHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: layout.bubble.size.height)

    let sidePadding = Theme.messageSidePadding
    let contentLeading = chatHasAvatar ? layout.nameAndBubbleLeading : sidePadding

    // Depending on outgoing or incoming message
    let contentViewSideAnchor =
      !outgoing ?
      contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading) :
      contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sidePadding)
    let bubbleViewSideAnchor =
      !outgoing ?
      bubbleView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentLeading) :
      bubbleView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sidePadding)

    constraints.append(
      contentsOf: [
        bubbleViewHeightConstraint,
        bubbleViewWidthConstraint,
        bubbleViewSideAnchor,

        contentViewHeightConstraint,
        contentViewWidthConstraint,
        contentViewSideAnchor,
      ]
    )

    // Text

    if let text = layout.text {
      textViewWidthConstraint = textView.widthAnchor
        .constraint(equalToConstant: text.size.width)
      textViewHeightConstraint = textView.heightAnchor
        .constraint(equalToConstant: text.size.height)
      textViewTopConstraint = textView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: layout.textContentViewTop
      )

      constraints.append(
        contentsOf: [
          textViewHeightConstraint!,
          textViewWidthConstraint!,
          textViewTopConstraint!,
          textView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: text.spacing.left
          ),
        ]
      )

      // TODO: Handle RTL
    }

    // Reactions
    if let reactionsPlan = layout.reactions, let reactionsView {
      reactionViewHeightConstraint = reactionsView.heightAnchor.constraint(
        equalToConstant: reactionsPlan.size.height
      )
      reactionViewWidthConstraint = reactionsView.widthAnchor.constraint(
        equalToConstant: reactionsPlan.size.width
      )
      reactionViewTopConstraint = reactionsView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: layout.reactionsViewTop
      )

      constraints.append(
        contentsOf: [
          reactionViewHeightConstraint,
          reactionViewWidthConstraint,
          reactionViewTopConstraint,
          reactionsView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: reactionsPlan.spacing.left
          ),
        ]
      )
    }

    // Time
    if let time = layout.time {
      constraints.append(
        contentsOf: [
          timeAndStateView.widthAnchor.constraint(
            equalToConstant: time.size.width
          ),
          timeAndStateView.heightAnchor.constraint(
            equalToConstant: time.size.height
          ),
          timeAndStateView.trailingAnchor
            .constraint(
              equalTo: bubbleView.trailingAnchor,
              constant: -time.spacing.right
            ),
          timeAndStateView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -time.spacing.bottom),
        ]
      )
    }

    if let reply = layout.reply {
      replyViewTopConstraint = replyView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: reply.spacing.top
      )

      constraints.append(
        contentsOf: [
          replyView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: reply.spacing.left),
          replyView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -reply.spacing.right),
          replyViewTopConstraint!,
        ]
      )
    }

    // Document
    if let document = layout.document, let documentView {
      documentViewTopConstraint = documentView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: layout.documentContentViewTop
      )

      constraints.append(
        contentsOf: [
          documentViewTopConstraint!,
          documentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: document.spacing.left),
          documentView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -document.spacing.right
          ),
        ]
      )
    }

    // Photo

    if let photo = layout.photo {
      photoViewTopConstraint = newPhotoView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: layout.photoContentViewTop
      )
      photoViewHeightConstraint = newPhotoView.heightAnchor.constraint(equalToConstant: photo.size.height)
      photoViewWidthConstraint = newPhotoView.widthAnchor
        .constraint(equalToConstant: photo.size.width)
      constraints.append(contentsOf: [
        photoViewTopConstraint!,
        photoViewHeightConstraint!,
        photoViewWidthConstraint!,
        newPhotoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: photo.spacing.left),
      ])
    }
  }

  // MARK: - Constraints

  private var textViewWidthConstraint: NSLayoutConstraint?
  private var textViewHeightConstraint: NSLayoutConstraint?
  private var textViewTopConstraint: NSLayoutConstraint?

  private var photoViewHeightConstraint: NSLayoutConstraint?
  private var photoViewWidthConstraint: NSLayoutConstraint?
  private var photoViewTopConstraint: NSLayoutConstraint?

  private var replyViewTopConstraint: NSLayoutConstraint?

  private var documentViewTopConstraint: NSLayoutConstraint?

  private var reactionViewWidthConstraint: NSLayoutConstraint!
  private var reactionViewHeightConstraint: NSLayoutConstraint!
  private var reactionViewTopConstraint: NSLayoutConstraint!

  private var contentViewWidthConstraint: NSLayoutConstraint!
  private var contentViewHeightConstraint: NSLayoutConstraint!

  private var bubbleViewWidthConstraint: NSLayoutConstraint!
  private var bubbleViewHeightConstraint: NSLayoutConstraint!

  private var isInitialUpdateConstraint = true

  override func updateConstraints() {
    if isInitialUpdateConstraint {
      setupConstraints()
      isInitialUpdateConstraint = false
      super.updateConstraints()
      return
    }

    // Update constraints if changed
    if let text = props.layout.text,
       let textViewWidthConstraint,
       let textViewHeightConstraint,
       let textViewTopConstraint
    {
      log.trace("Updating text view constraints for message \(text.size)")
      if textViewWidthConstraint.constant != text.size.width {
        textViewWidthConstraint.constant = text.size.width
      }

      if textViewHeightConstraint.constant != text.size.height {
        textViewHeightConstraint.constant = text.size.height
      }

      if textViewTopConstraint.constant != props.layout.textContentViewTop {
        textViewTopConstraint.constant = props.layout.textContentViewTop
      }
    }

    if let reply = props.layout.reply,
       let replyViewTopConstraint
    {
      log.trace("Updating reply view constraints for message \(reply.size)")
      if replyViewTopConstraint.constant != reply.spacing.top {
        replyViewTopConstraint.constant = reply.spacing.top
      }
    }

    if let photo = props.layout.photo,
       let photoViewHeightConstraint,
       let photoViewWidthConstraint,
       let photoViewTopConstraint
    {
      log.trace("Updating photo view constraints for message \(photo.size)")
      if photoViewHeightConstraint.constant != photo.size.height {
        photoViewHeightConstraint.constant = photo.size.height
      }

      if photoViewWidthConstraint.constant != photo.size.width {
        photoViewWidthConstraint.constant = photo.size.width
      }

      if photoViewTopConstraint.constant != props.layout.photoContentViewTop {
        photoViewTopConstraint.constant = props.layout.photoContentViewTop
      }
    }

    if let document = props.layout.document,
       let documentViewTopConstraint
    {
      log.trace("Updating document view constraints for message \(document.size)")
      if documentViewTopConstraint.constant != document.spacing.top {
        documentViewTopConstraint.constant = document.spacing.top
      }
    }

    if let bubbleViewWidthConstraint,
       let bubbleViewHeightConstraint,
       let contentViewWidthConstraint,
       let contentViewHeightConstraint
    {
      let bubble = props.layout.bubble
      log.trace("Updating bubble view constraints for message \(bubble.size)")
      if bubbleViewWidthConstraint.constant != bubble.size.width {
        bubbleViewWidthConstraint.constant = bubble.size.width
      }

      if bubbleViewHeightConstraint.constant != bubble.size.height {
        bubbleViewHeightConstraint.constant = bubble.size.height
      }

      if contentViewWidthConstraint.constant != bubble.size.width {
        contentViewWidthConstraint.constant = bubble.size.width
      }

      if contentViewHeightConstraint.constant != bubble.size.height {
        contentViewHeightConstraint.constant = bubble.size.height
      }
    }

    // Update reaction constraints
    if let reactionsPlan = props.layout.reactions,
       let reactionViewWidthConstraint,
       let reactionViewHeightConstraint,
       let reactionViewTopConstraint
    {
      log.trace("Updating reactions view constraints for message \(reactionsPlan.size)")
      if reactionViewWidthConstraint.constant != reactionsPlan.size.width {
        reactionViewWidthConstraint.constant = reactionsPlan.size.width
      }

      if reactionViewHeightConstraint.constant != reactionsPlan.size.height {
        reactionViewHeightConstraint.constant = reactionsPlan.size.height
      }

      if reactionViewTopConstraint.constant != props.layout.reactionsViewTop {
        reactionViewTopConstraint.constant = props.layout.reactionsViewTop
      }
    } else if let reactionsView, let reactionsPlan = props.layout.reactions {
      // setup
      reactionViewHeightConstraint = reactionsView.heightAnchor.constraint(
        equalToConstant: reactionsPlan.size.height
      )
      reactionViewWidthConstraint = reactionsView.widthAnchor.constraint(
        equalToConstant: reactionsPlan.size.width
      )
      reactionViewTopConstraint = reactionsView.topAnchor.constraint(
        equalTo: contentView.topAnchor,
        constant: props.layout.reactionsViewTop
      )
      NSLayoutConstraint.activate([
        reactionViewHeightConstraint,
        reactionViewWidthConstraint,
        reactionViewTopConstraint,
        reactionsView.leadingAnchor.constraint(
          equalTo: contentView.leadingAnchor,
          constant: reactionsPlan.spacing.left
        ),
      ])
    }
//    if hasReactions {
//      for (index, reaction) in reactionItems.enumerated() {
//        if let constraints = reactionItemConstraints[reaction] {
//          let newLeadingConstant = CGFloat(index) *
//            (props.layout.reactionsSize.width + props.layout.reactionsSpacing.left)
//          if constraints.leading.constant != newLeadingConstant {
//            constraints.leading.constant = newLeadingConstant
//          }
//
//          if constraints.width.constant != props.layout.reactionsSize.width {
//            constraints.width.constant = props.layout.reactionsSize.width
//          }
//
//          if constraints.height.constant != props.layout.reactionsSize.height {
//            constraints.height.constant = props.layout.reactionsSize.height
//          }
//        }
//      }
//    }

    super.updateConstraints()
  }

  private func setupMessageText() {
    guard hasText else { return }

    // Get display text which handles translations
    let translationText = fullMessage.translationText
    let showingTranslatedText = fullMessage.translationText != nil
    let text = translationText ?? fullMessage.message.text ?? ""

    // From Cache

    if
      let cachedAttributedString = CacheAttrs.shared.get(message: fullMessage)
    {
      let attributedString = cachedAttributedString
      textView.textStorage?.setAttributedString(attributedString)

      if useTextKit2 {
        textView.textContainer?.size = props.layout.text?.size ?? .zero
      } else {
        textView.textContainer?.size = props.layout.text?.size ?? .zero
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
      }
      return
    }

    /// Apply entities to text and create an NSAttributedString
    let attributedString = ProcessEntities.toAttributedString(
      text: text,
      entities: fullMessage.message.entities,
      configuration: .init(
        font: MessageTextConfiguration.font,
        textColor: textColor,
        linkColor: mentionColor,
      )
    )

    // Detect and add links
    if let detector = Self.detector {
      let matches = detector.matches(
        in: text,
        options: [],
        range: NSRange(location: 0, length: text.utf16.count)
      )

      for match in matches {
        if let url = match.url {
          attributedString.addAttributes([
            .cursor: NSCursor.pointingHand,
            .link: url,
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
          ], range: match.range)
        }
      }
    }

    textView.textStorage?.setAttributedString(attributedString)

    CacheAttrs.shared.set(message: fullMessage, value: attributedString)

    if useTextKit2 {
      textView.textContainer?.size = props.layout.text?.size ?? .zero
    } else {
      textView.textContainer?.size = props.layout.text?.size ?? .zero
      textView.layoutManager?.ensureLayout(for: textView.textContainer!)
    }
  }

  static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

  func reflectBoundsChange(fraction uncappedFraction: CGFloat) {}

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    // Experimental in build 66
    // Adjust viewport instead of layouting
    if window != nil {
      // Register for both frame and bounds changes
//      NotificationCenter.default.addObserver(
//        self,
//        selector: #selector(handleBoundsChange),
//        name: NSView.frameDidChangeNotification,
//        object: enclosingScrollView?.contentView
//      )

      ////      // Also observe bounds changes
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleBoundsChange),
        name: NSView.boundsDidChangeNotification,
        object: enclosingScrollView?.contentView
      )

//      // Observe window resize notifications
//      NotificationCenter.default.addObserver(
//        self,
//        selector: #selector(handleBoundsChange),
//        name: NSWindow.didResizeNotification,
//        object: window
//      )
    }
  }

  private var prevWidth: CGFloat = 0

  // Fix a bug that when messages were out of viewport and came back during a live resize
  // text would not appear until the user ended live resize operation. Seems like in TextKit 2 calling layoutViewport
  // solves this.
  // The property `allowsNonContiguousLayout` also seems to fix this issue but it has two other issues:
  // 1. that forces textkit 1
  // 2. it adds a scroll jump everytime user resizes the window
  // which made it unsusable.
  // This approach still needs further testing.
  @objc private func handleBoundsChange(_ notification: Notification) {
    guard let scrollView = enclosingScrollView,
          let clipView = notification.object as? NSClipView else { return }

    boundsChange(scrollView: scrollView, clipView: clipView)
  }

  private var prevInViewport = false

  private func boundsChange(scrollView: NSScrollView, clipView: NSClipView) {
    guard feature_relayoutOnBoundsChange else { return }
    guard hasText else { return }
    // guard textView.inLiveResize else { return }

    let visibleRect = scrollView.documentVisibleRect
    let textViewRect = convert(bounds, to: clipView)
    let inViewport = visibleRect.insetBy(dx: 0.0, dy: 60.0).intersects(
      textViewRect
    )

    if !prevInViewport, inViewport {
      if textView.inLiveResize {
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
      }
      log
        .trace(
          "Layouting viewport for text view \(message.id)"
        )
      prevInViewport = true
    }
    if !inViewport {
      prevInViewport = false
    }
  }

  // MARK: - Context Menu

  private func setupContextMenu() {
    menu = createMenu(context: .message)
  }

  @objc private func addReaction() {
    // Show reaction overlay
    showReactionOverlay()
  }

  @objc private func copyMessage() {
    NSPasteboard.general.clearContents()

    // Old
    // NSPasteboard.general.setString(message.text ?? "", forType: .string)

    // Copy Translation
    NSPasteboard.general
      .setString(fullMessage.displayText ?? "", forType: .string)
  }

  @objc private func deleteMessage() {
    let _ = Transactions.shared.mutate(
      transaction: .deleteMessage(
        .init(
          messageIds: [message.messageId],
          peerId: message.peerId,
          chatId: message.chatId
        )
      )
    )
  }

  @objc private func reply() {
    let state = ChatsManager
      .get(
        for: fullMessage.peerId,
        chatId: fullMessage.chatId
      )

    state.setReplyingToMsgId(fullMessage.message.messageId)
  }

  @objc private func editMessage() {
    let state = ChatsManager
      .get(
        for: fullMessage.peerId,
        chatId: fullMessage.chatId
      )

    state.setEditingMsgId(fullMessage.message.messageId)
  }

  @objc private func saveDocument() {
    guard let documentInfo = fullMessage.documentInfo else { return }

    // Get the source file URL
    let cacheDirectory = FileHelpers.getLocalCacheDirectory(for: .documents)
    guard let localPath = documentInfo.document.localPath else { return }
    let sourceURL = cacheDirectory.appendingPathComponent(localPath)

    // Get the Downloads directory
    let fileManager = FileManager.default
    let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!

    // Get the filename
    let fileName = documentInfo.document.fileName ?? "Unknown File"

    // Create a save panel
    let savePanel = NSSavePanel()
    savePanel.nameFieldStringValue = fileName
    savePanel.directoryURL = downloadsURL
    savePanel.canCreateDirectories = true

    savePanel.beginSheetModal(for: window!) { response in
      if response == .OK, let destinationURL = savePanel.url {
        do {
          try fileManager.copyItem(at: sourceURL, to: destinationURL)
          NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } catch {
          print("Error saving document: \(error)")
        }
      }
    }
  }

  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
    // Apply selection style when menu is about to open
    layer?.backgroundColor = NSColor.darkGray
      .withAlphaComponent(0.05).cgColor
  }

  override func didCloseMenu(_ menu: NSMenu, with event: NSEvent?) {
    // Remove selection style when menu closes
    layer?.backgroundColor = nil
  }

  // MARK: - View Updates

  private func updatePropsAndUpdateLayout(
    props: MessageViewProps,
    disableTextRelayout: Bool = false,
    animate: Bool = false
  ) {
    // update internal props (must update so contentView is recalced)
    self.props = props

    if textView.textContainer?.size != props.layout.text?.size ?? .zero {
      log.trace("updating size for text in msg \(message.id)")
      textView.textContainer?.size = props.layout.text?.size ?? .zero
    }

    layoutSubtreeIfNeeded()

    needsUpdateConstraints = true

    if animate {
      // Animate the changes
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.15
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        context.allowsImplicitAnimation = true

        // self.animator().layoutSubtreeIfNeeded()
        self.layoutSubtreeIfNeeded()
      } completionHandler: { [weak self] in
        // Completion block
        DispatchQueue.main.async {
          // Fixes text display issues going blank
          self?.textView.textLayoutManager?.textViewportLayoutController
            .layoutViewport()
        }
      }
    }
  }

  public func updateTextAndSize(fullMessage: FullMessage, props: MessageViewProps, animate: Bool = false) {
    log.trace(
      "Updating message view content. from: \(self.fullMessage.message.messageId) to: \(fullMessage.message.messageId)"
    )

    let prev = self.fullMessage

    prevInViewport = false

    // update internal props
    self.fullMessage = fullMessage

    // Update props and reflect changes
    updatePropsAndUpdateLayout(props: props, disableTextRelayout: true, animate: animate)

    // Reactions
    // if hasReactions {
    updateReactions(prev: prev, next: fullMessage, props: props)
    // }

    // Text
    setupMessageText()

    // Photo
    if hasPhoto {
      newPhotoView.update(with: fullMessage)
    }

    // Document
    if hasDocument, let documentView {
      if let documentInfo = fullMessage.documentInfo {
        documentView.update(with: documentInfo)
      }
    }

    // Update time and state
    timeAndStateView.updateMessage(fullMessage)

    DispatchQueue.main.async(qos: .utility) { [weak self] in
      // As the message changes here, we need to update everything related to that. Otherwise we get wrong context menu.
      self?.setupContextMenu()
    }
  }

  public func updateSize(props: MessageViewProps) {
    // update props and reflect changes
    updatePropsAndUpdateLayout(
      props: props,
      // disableTextRelayout: props.layout.singleLine // Quick hack to reduce such re-layouts
      disableTextRelayout: true
    )

    // if hasReactions {
    updateReactionsSizes()
    // }
  }

  private func setTimeAndStateVisibility(visible: Bool) {
//    NSAnimationContext.runAnimationGroup { context in
//      context.duration = visible ? 0.05 : 0.05
//      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
//      context.allowsImplicitAnimation = true
//      timeAndStateView.layer?.opacity = visible ? 1 : 0
//    }
  }

  // MARK: - Actions

  // ---
  private var notificationObserver: NSObjectProtocol?
  private var scrollState: MessageListScrollState = .idle {
    didSet {
      if hasPhoto {
        if scrollState == .idle {
          newPhotoView.setIsScrolling(false)
        } else {
          newPhotoView.setIsScrolling(true)
        }
      }
    }
  }

  private var hoverTrackingArea: NSTrackingArea?
  private func setupScrollStateObserver() {
    notificationObserver = NotificationCenter.default.addObserver(
      forName: .messageListScrollStateDidChange,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let state = notification.userInfo?["state"] as? MessageListScrollState else { return }
      self?.handleScrollStateChange(state)
    }
  }

  // MARK: - Swipe to Reply

  // Track swipe state
  private var isSwipeInProgress = false
  private var swipeOffset: CGFloat = 0
  private var swipeAnimationView: NSView?
  private var hasTriggerHapticFeedback = false
  private var swipeThreshold: CGFloat = 50.0
  private var didReachThreshold = false

  override func scrollWheel(with event: NSEvent) {
    // Only handle horizontal scrolling with two fingers
    if event.phase == .began, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
      // Start of a horizontal scroll
      isSwipeInProgress = true
      swipeOffset = 0
      hasTriggerHapticFeedback = false
      didReachThreshold = false

      // Create animation view if needed
      if swipeAnimationView == nil {
        swipeAnimationView = createReplyIndicator()
        addSubview(swipeAnimationView!)
        swipeAnimationView?.alphaValue = 0
      }

      // Position the animation view
      if let animView = swipeAnimationView {
        let yPosition = bubbleView.bounds.midY - animView.bounds.height / 2
        animView.frame.origin = NSPoint(x: bounds.width, y: yPosition)
      }
    }

    if isSwipeInProgress {
      // Update swipe offset based on scroll delta
      // Note: scrollingDeltaX is positive for right-to-left swipes on some systems
      // We need to ensure we're getting a negative value for left swipes
      let deltaX = event.scrollingDeltaX

      // Adjust the swipe offset - we want negative values for left swipes
      swipeOffset += deltaX

      // Only handle left swipes (negative swipeOffset)
      if swipeOffset < 0 {
        // Calculate swipe progress (0 to 1)
        let progress = min(1.0, abs(swipeOffset) / swipeThreshold)

        // Update position using layer transform on self
        let maxOffset: CGFloat = 40.0
        let offset = -min(maxOffset, abs(swipeOffset)) // Negative for left movement

        // Apply transform to root view layer
        wantsLayer = true
        let transform = CATransform3DMakeTranslation(offset, 0, 0)
        layer?.transform = transform

        // Update animation view
        swipeAnimationView?.alphaValue = progress

        // Track if we've reached the threshold
        let hasReachedThreshold = abs(swipeOffset) > swipeThreshold

        // Only trigger haptic feedback when first crossing the threshold
        if hasReachedThreshold, !didReachThreshold {
          NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
          didReachThreshold = true
          hasTriggerHapticFeedback = true
        } else if !hasReachedThreshold, didReachThreshold {
          // We've moved back below the threshold
          didReachThreshold = false
        }
      } else {
        // Reset for right swipes
        layer?.transform = CATransform3DIdentity
        swipeAnimationView?.alphaValue = 0
      }

      // End of swipe gesture
      if event.phase == .ended || event.phase == .cancelled {
        isSwipeInProgress = false

        let direction = swipeOffset > 0 ? "right" : "left"

        // Check if swipe was far enough to trigger reply
        if abs(swipeOffset) > swipeThreshold, direction == "left" {
          Task(priority: .userInitiated) { @MainActor in self.reply() }

          // Animate back with spring effect
          NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.layer?.transform = CATransform3DIdentity
            swipeAnimationView?.animator().alphaValue = 0
          }) {}
        } else {
          // Not far enough, just animate back
          NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.layer?.transform = CATransform3DIdentity
            swipeAnimationView?.animator().alphaValue = 0
          }
        }

        // Reset state
        hasTriggerHapticFeedback = false
        didReachThreshold = false
      }
    } else {
      // Pass the event to super if we're not handling it
      super.scrollWheel(with: event)
    }
  }

  private func createReplyIndicator() -> NSView {
    // Create a smaller indicator (24x24 pixels)
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    container.wantsLayer = true
    container.layer?.cornerRadius = 12
    container.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor

    // Add reply icon (smaller size)
    let iconView = NSImageView(frame: NSRect(x: 4, y: 4, width: 16, height: 16))
    if let replyImage = NSImage(systemSymbolName: "arrowshape.turn.up.left.fill", accessibilityDescription: "Reply") {
      iconView.image = replyImage
      iconView.contentTintColor = NSColor.controlAccentColor
      container.addSubview(iconView)
    }

    return container
  }

  func reset() {
    // Cancel translation state observation
    translationStateCancellable?.cancel()
    translationStateCancellable = nil

    // Remove shine effect
    shineEffectView?.stopAnimation()
    shineEffectView?.removeFromSuperview()
    shineEffectView = nil

    // Re-setup translation state observation
    setupTranslationStateObservation()
  }

  @objc private func cancelMessage() {
    Log.shared.debug("Canceling message")
    if let transactionId = message.transactionId, !transactionId.isEmpty {
      Transactions.shared.cancel(transactionId: transactionId)
    }
    let chatId = message.chatId
    let messageId = message.messageId
    Task(priority: .userInitiated) {
      let _ = try? await AppDatabase.shared.dbWriter.write { db in
        try Message
          .filter(Column("chatId") == chatId)
          .filter(Column("messageId") == messageId)
          .deleteAll(db)
      }

      MessagesPublisher.shared
        .messagesDeleted(messageIds: [message.messageId], peer: message.peerId)
    }
  }
}

// MARK: - Tracking Area & Hover

extension MessageViewAppKit {
  public func setScrollState(_ state: MessageListScrollState) {
    handleScrollStateChange(state)
  }

  private func handleScrollStateChange(_ state: MessageListScrollState) {
    scrollState = state
    switch state {
      case .scrolling:
        // Clear hover state
        updateHoverState(false)
      case .idle:
        break
        // Re-enable hover state if needed
        // TODO: How can I check if mouse is inside the view?
        // addHoverTrackingArea()
    }
  }

  var shouldAlwaysShowTimeAndState: Bool {
    message.status == .sending || message.status == .failed
  }

  private func updateHoverState(_ isHovered: Bool) {
    isMouseInside = isHovered
  }

  func removeHoverTrackingArea() {
    if let hoverTrackingArea {
      removeTrackingArea(hoverTrackingArea)
    }
  }

  func addHoverTrackingArea() {
    removeHoverTrackingArea()
    hoverTrackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(hoverTrackingArea!)
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    guard scrollState == .idle else { return }
    updateHoverState(true)
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    updateHoverState(false)
  }
}

extension MessageViewAppKit: NSTextViewDelegate {
  func textView(_ textView: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
    createMenu(context: .textView, nativeMenu: menu)
  }
}

extension MessageViewAppKit: NSMenuDelegate {
  enum MenuContext {
    case message
    case textView
  }

  func createMenu(context: MenuContext, nativeMenu: NSMenu? = nil) -> NSMenu {
    let menu = NSMenu()

    let regularMessage = message.status != .sending && message.status != .failed

    // Reply
    if regularMessage {
      let replyItem = NSMenuItem(title: "Reply", action: #selector(reply), keyEquivalent: "r")
      replyItem.image = NSImage(systemSymbolName: "arrowshape.turn.up.left", accessibilityDescription: "Reply")
      menu.addItem(replyItem)
    }

    // Edit
    if message.out == true, message.status == .sent {
      let editItem = NSMenuItem(title: "Edit", action: #selector(editMessage), keyEquivalent: "e")
      editItem.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Edit")
      menu.addItem(editItem)
    }

    if regularMessage {
      // Add reaction action
      let addReactionItem = NSMenuItem(title: "Add Reaction...", action: #selector(addReaction), keyEquivalent: "e")
      addReactionItem.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Add Reaction")
      menu.addItem(addReactionItem)
    }

    if menu.items.count > 0 {
      menu.addItem(NSMenuItem.separator())
    }

    var rendersCopyText = false

    // Add native copy for selected text if in text view context
    if context == .textView,
       let nativeMenu,
       let nativeCopyItem = nativeMenu.items.first(where: { $0.title == "Copy" })
    {
      let newItem = nativeCopyItem.copy() as! NSMenuItem
      newItem.title = "Copy Selected Text"
      menu.addItem(newItem)
      rendersCopyText = true
    }

    // Add copy message action for text
    if hasText {
      let copyItem = NSMenuItem(title: "Copy Message", action: #selector(copyMessage), keyEquivalent: "c")
      if !rendersCopyText {
        copyItem.image = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: "Copy")
        rendersCopyText = true
      }
      menu.addItem(copyItem)
    }

    // Add photo actions
    if hasPhoto {
      let copyItem = NSMenuItem(title: "Copy Image", action: #selector(newPhotoView.copyImage), keyEquivalent: "i")
      copyItem.target = newPhotoView
      copyItem.isEnabled = true
      if !rendersCopyText {
        copyItem.image = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: "Copy")
      }
      menu.addItem(copyItem)
    }

    if hasPhoto {
      menu.addItem(NSMenuItem.separator())
      let saveItem = NSMenuItem(title: "Save Image", action: #selector(newPhotoView.saveImage), keyEquivalent: "m")
      saveItem.target = newPhotoView
      saveItem.isEnabled = true
      saveItem.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save Image")
      menu.addItem(saveItem)
    }

    // Add document actions
    if hasDocument {
      menu.addItem(NSMenuItem.separator())
      let saveItem = NSMenuItem(title: "Save Document", action: #selector(saveDocument), keyEquivalent: "s")
      saveItem.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save Document")
      menu.addItem(saveItem)
    }

    // Add other native menu items if in text view context
    if context == .textView, let nativeMenu {
      menu.addItem(NSMenuItem.separator())

      for item in nativeMenu.items {
        if item.title.hasPrefix("Look Up") {
          let newItem = item.copy() as! NSMenuItem
          newItem.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Save Document")
          menu.addItem(newItem)
        }

        if item.title.hasPrefix("Translate") {
          let newItem = item.copy() as! NSMenuItem
          menu.addItem(newItem)
        }
      }
    }

    menu.addItem(NSMenuItem.separator())

    // Delete or cancel button
    if message.status == .sending {
      let cancelItem = NSMenuItem(title: "Cancel", action: #selector(cancelMessage), keyEquivalent: "delete")
      cancelItem.target = self
      cancelItem.image = NSImage(systemSymbolName: "x.circle", accessibilityDescription: "Cancel")
      menu.addItem(cancelItem)
    } else {
      let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteMessage), keyEquivalent: "delete")
      deleteItem.target = self
      deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
      menu.addItem(deleteItem)
    }

    /// If message is edited, show edit date in context menu
    if let editDate = message.editDate {
      menu.addItem(NSMenuItem.separator())
      let formatted = DateFormatter.localizedString(from: editDate, dateStyle: .medium, timeStyle: .short)
      let editDateItem = NSMenuItem(title: "Edited \(formatted)", action: nil, keyEquivalent: "")
      editDateItem.isEnabled = false
      menu.addItem(editDateItem)
    }

    #if DEBUG
    menu.addItem(NSMenuItem.separator())

    // Add debug items
    let idItem = NSMenuItem(title: "ID: \(message.id)", action: nil, keyEquivalent: "")
    idItem.isEnabled = false
    menu.addItem(idItem)

    let indexItem = NSMenuItem(
      title: "Index: \(props.index?.description ?? "?")",
      action: nil,
      keyEquivalent: ""
    )
    indexItem.isEnabled = false
    menu.addItem(indexItem)

    #endif

    menu.delegate = self
    return menu
  }
}

struct MessageViewInputProps: Equatable, Codable, Hashable {
  var firstInGroup: Bool
  var isLastMessage: Bool
  var isFirstMessage: Bool
  var isDM: Bool
  var isRtl: Bool
  var translated: Bool

  /// Used in cache key
  func toString() -> String {
    "\(firstInGroup ? "FG" : "")\(isLastMessage == true ? "LM" : "")\(isFirstMessage == true ? "FM" : "")\(isRtl ? "RTL" : "")\(isDM ? "DM" : "")\(translated ? "TR" : "")"
  }
}

struct MessageViewProps: Equatable, Codable, Hashable {
  var firstInGroup: Bool
  var isLastMessage: Bool
  var isFirstMessage: Bool
  var isRtl: Bool
  var isDM: Bool = false
  var index: Int?
  var translated: Bool
  var layout: MessageSizeCalculator.LayoutPlans

  func equalExceptSize(_ rhs: MessageViewProps) -> Bool {
    firstInGroup == rhs.firstInGroup &&
      isLastMessage == rhs.isLastMessage &&
      isFirstMessage == rhs.isFirstMessage &&
      isRtl == rhs.isRtl &&
      isDM == rhs.isDM &&
      translated == rhs.translated
  }
}

// Helper extension for constraint priorities
private extension NSLayoutConstraint {
  func withPriority(_ priority: NSLayoutConstraint.Priority) -> NSLayoutConstraint {
    self.priority = priority
    return self
  }
}

//// Implement viewport constraint
extension MessageViewAppKit: NSTextViewportLayoutControllerDelegate {
  func textViewportLayoutController(
    _ textViewportLayoutController: NSTextViewportLayoutController,
    configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment
  ) {
    prevDelegate?.textViewportLayoutController(
      textViewportLayoutController,
      configureRenderingSurfaceFor: textLayoutFragment
    )
  }

  func textViewportLayoutControllerWillLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
    prevDelegate?.textViewportLayoutControllerWillLayout?(textViewportLayoutController)
  }

  func textViewportLayoutControllerDidLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
    prevDelegate?.textViewportLayoutControllerDidLayout?(textViewportLayoutController)
  }

  func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
    // During resize, we need to be more aggressive with the viewport size
    let visibleRect = enclosingScrollView?.documentVisibleRect ?? textView.visibleRect

    // Create a larger viewport during resize to ensure text remains visible
    let expandedRect = visibleRect.insetBy(dx: -100, dy: -500)

    // Convert to text view coordinates if needed
    let textViewRect = textView.convert(expandedRect, from: enclosingScrollView?.contentView)

    return textViewRect
  }
}

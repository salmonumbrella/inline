import AppKit
import Cocoa
import Foundation
import SwiftUI

// System colors: https://gist.github.com/andrejilderda/8677c565cddc969e6aae7df48622d47c

enum Theme {
  // MARK: - General

  static let pageBackgroundMaterial: NSVisualEffectView.Material = .contentBackground
  static let whiteOnLight: NSColor = .init(name: "whiteOrBlack") { appearance in
    appearance.name == .darkAqua ? NSColor.black : NSColor.white
  }

  // MARK: - Colors

  static let colorIconGray: NSColor = .init(name: "colorIconGray") { _ in
    NSColor(red: 166 / 255, green: 173 / 255, blue: 200 / 255, alpha: 1)
  }

  static let colorTitleTextGray: NSColor = .init(name: "colorTitleTextGray") { _ in
    NSColor(red: 186 / 255, green: 194 / 255, blue: 222 / 255, alpha: 1)
  }

  // MARK: - Window

  static let windowMinimumSize: CGSize = .init(width: 320, height: 300)

  // MARK: - Main View & Split View

  static let collapseSidebarAtWindowSize: CGFloat = 500

  // MARK: - Sidebar

  /// 190 is minimum that fits both sidebar collapse button and plus button
  static let minimumSidebarWidth: CGFloat = 200
  static let idealSidebarWidth: CGFloat = 240
  static let sidebarItemRadius: CGFloat = 10
  static let sidebarItemPadding: CGFloat = 7.0
  // extra to above padding. note: weird thing is making this 3.0 fucks up home sidebar.
  static let sidebarItemLeadingGutter: CGFloat = 4.0
  static let sidebarItemSpacing: CGFloat = 1
  static let sidebarTopItemFont: Font = .body.weight(.regular)
  static let sidebarTopItemHeight: CGFloat = 24

  static let sidebarIconSpacing: CGFloat = 9
  static let sidebarTitleIconSize: CGFloat = 24
  static let sidebarIconSize: CGFloat = 24
  static let sidebarItemHeight: CGFloat = 34
  static let sidebarTitleItemFont: Font = .system(size: 13.0, weight: .medium)
  static let sidebarItemFont: Font = .system(size: 13.0, weight: .regular)
  static let sidebarContentSideSpacing: CGFloat = 17.0 // from inner content of item to edge of sidebar
  static let sidebarItemInnerSpacing: CGFloat = 11.0 // from inner content of item to edge of content active/hover style
  static let sidebarItemOuterSpacing: CGFloat = Theme.sidebarContentSideSpacing - Theme.sidebarItemInnerSpacing
  static let sidebarNativeDefaultEdgeInsets: CGFloat = 16.0

  // MARK: - Message View

  static let messageMaxWidth: CGFloat = 420
  static let messageOuterVerticalPadding: CGFloat = 1.0 // gap between consequetive messages
  static let messageSidePadding: CGFloat = 16.0
  static let messageAvatarSize: CGFloat = 28
  // between avatar and content
  static let messageHorizontalStackSpacing: CGFloat = 8.0
  static let messageNameLabelHeight: CGFloat = 16
  static let messageTextFont: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
  static let messageTextLineFragmentPadding: CGFloat = 0
  static let messageTextContainerInset: NSSize = .zero
  static let messageTextViewPadding: CGFloat = 0
  static let messageContentViewSpacing: CGFloat = 8.0
  static var messageRowMaxWidth: CGFloat {
    Theme.messageMaxWidth + Theme.messageAvatarSize + Theme.messageSidePadding + Theme
      .messageHorizontalStackSpacing + Theme.messageRowSafeAreaInset
  }

  // - after bubble -
  static let messageBubblePrimaryBgColor: NSColor = .init(name: "messageBubblePrimaryBgColor") { _ in
    NSColor(
      calibratedRed: 137 / 255,
      green: 180 / 255,
      blue: 250 / 255,
      alpha: 1.0
    )
  }

  static let messageBubbleSecondaryBgColor: NSColor = .init(name: "messageBubbleSecondaryBgColor") { _ in
    NSColor(
      calibratedRed: 69 / 255,
      green: 71 / 255,
      blue: 90 / 255,
      alpha: 1.0
    )
  }

  /// used for bubbles diff to edge
  static let messageRowSafeAreaInset: CGFloat = 50.0
  static let messageBubbleContentHorizontalInset: CGFloat = 11.0
  static let messageSingleLineTextOnlyHeight: CGFloat = 28.0
  static let messageBubbleCornerRadius: CGFloat = 14.0
  static let messageTimeHeight: CGFloat = 13.0
  static let messageTextOnlyVerticalInsets: CGFloat = 6.0
  static let messageTextAndPhotoSpacing: CGFloat = 10.0
  static let messageTextAndTimeSpacing: CGFloat = 0.0

  // MARK: - Chat View

  static let chatToolbarIconSize: CGFloat = 30
  static let chatViewMinWidth: CGFloat = 315 // going below this makes media calcs mess up
  static let messageGroupSpacing: CGFloat = 8
  static let messageListTopInset: CGFloat = 14
  static let messageListBottomInset: CGFloat = 10
  static let embeddedMessageHeight: CGFloat = 40.0
  static let documentViewHeight: CGFloat = 36.0
  static let documentViewWidth: CGFloat = 200.0
  static let scrollButtonSize: CGFloat = 32.0

  static let composeMinHeight: CGFloat = 44
  static let composeAttachmentsVPadding: CGFloat = 6
  static let composeAttachmentImageHeight: CGFloat = 80
  static let composeButtonSize: CGFloat = 28
  static let composeTextViewHorizontalPadding: CGFloat = 10.0
  static let composeVerticalPadding: CGFloat = 2.0 // inner, higher makes 2 line compose increase height
  static let composeOuterSpacing: CGFloat = 18 // horizontal
  static let composeOutlineColor: NSColor = .init(name: "composeOutlineColor") { _ in
    NSColor(
      calibratedRed: 88 / 255,
      green: 91 / 255,
      blue: 112 / 255,
      alpha: 1.0
    )
  }

  // MARK: - Devtools

  static let devtoolsHeight: CGFloat = 30
}

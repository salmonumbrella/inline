import InlineKit
import SwiftUI

struct ChatListItem: View {
  let item: HomeChatItem
  let onTap: () -> Void
  let onArchive: () -> Void
  let onPin: () -> Void
  let onRead: () -> Void
  let isArchived: Bool

  @EnvironmentObject private var nav: Navigation
  @EnvironmentObject private var data: DataManager
  @Environment(\.realtime) var realtime
  @Environment(\.appDatabase) private var database

  var body: some View {
    Button(action: onTap) {
      if let user = item.user {
        DirectChatItem(props: Props(
          dialog: item.dialog,
          user: user,
          chat: item.chat,
          message: item.lastMessage
        ))
      } else if let chat = item.chat {
        ChatItemView(props: ChatItemProps(
          dialog: item.dialog,
          user: item.user,
          chat: chat,
          message: item.lastMessage,
          space: item.space
        ))
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive) {
        onArchive()
      } label: {
        Image(systemName: isArchived ? "tray.and.arrow.up.fill" : "tray.and.arrow.down.fill")
      }
      .tint(Color(.systemGray2))

      Button {
        onPin()
      } label: {
        Image(systemName: item.dialog.pinned ?? false ? "pin.slash.fill" : "pin.fill")
      }
      .tint(.indigo)
    }
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      Button(role: .destructive) {
        onRead()
      } label: {
        Image(systemName: "checkmark.message.fill")
      }
      .tint(.blue)
    }
    .listRowInsets(.init(top: 8, leading: 16, bottom: 2, trailing: 0))
//    .contextMenu {
//      Button {
//        onTap()
//      } label: {
//        Label("Open Chat", systemImage: "bubble.left")
//      }
//    } preview: {
//      if let user = item.user {
//        ChatView(peer: .user(id: user.user.id), preview: true)
//          .frame(width: Theme.shared.chatPreviewSize.width, height: Theme.shared.chatPreviewSize.height)
//          .environmentObject(nav)
//          .environmentObject(data)
//          .environment(\.realtime, realtime)
//          .environment(\.appDatabase, database)
//      } else if let chat = item.chat {
//        ChatView(peer: .thread(id: chat.id), preview: true)
//          .frame(width: Theme.shared.chatPreviewSize.width, height: Theme.shared.chatPreviewSize.height)
//          .environmentObject(nav)
//          .environmentObject(data)
//          .environment(\.realtime, realtime)
//          .environment(\.appDatabase, database)
//      }
//    }
  }
}

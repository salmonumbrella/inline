import { db } from '@in/server/db'
import { scheduledMessages } from '@in/server/db/schema'
import { sendMessage } from '@in/server/functions/messages.sendMessage'
import { lte, eq } from 'drizzle-orm'

const INTERVAL = 30_000

setInterval(async () => {
  const due = await db
    .select()
    .from(scheduledMessages)
    .where(lte(scheduledMessages.scheduledAt, new Date()))
    .where(eq(scheduledMessages.status, 'pending'))

  for (const m of due) {
    await db.transaction(async (tx) => {
      await sendMessage(
        { peerId: { chatId: m.channelId }, message: m.body },
        { currentUserId: m.authorId, currentSessionId: 0, ip: undefined }
      )
      await tx
        .update(scheduledMessages)
        .set({ status: 'sent', sentAt: new Date() })
        .where(eq(scheduledMessages.id, m.id))
    })
  }
}, INTERVAL)

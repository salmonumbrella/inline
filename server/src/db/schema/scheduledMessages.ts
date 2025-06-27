import { pgTable, integer, text, timestamp, pgEnum, index } from 'drizzle-orm/pg-core'
import { users } from './users'
import { chats } from './chats'
import { relations } from 'drizzle-orm/_relations'

export const scheduledMessageStatusEnum = pgEnum('scheduled_message_status', ['pending','sent','cancelled'])

export const scheduledMessages = pgTable(
  'scheduled_messages',
  {
    id: integer('id').generatedAlwaysAsIdentity().primaryKey(),
    channelId: integer('channel_id').references(() => chats.id, { onDelete: 'cascade' }).notNull(),
    authorId: integer('author_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
    body: text('body').notNull(),
    scheduledAt: timestamp('scheduled_at', { mode: 'date', withTimezone: true }).notNull(),
    createdAt: timestamp('created_at', { mode: 'date', withTimezone: true }).defaultNow().notNull(),
    sentAt: timestamp('sent_at', { mode: 'date', withTimezone: true }),
    status: scheduledMessageStatusEnum('status').default('pending').notNull(),
  },
  (table) => ({
    dueIdx: index('scheduled_messages_due_idx').on(table.scheduledAt),
  }),
)

export const scheduledMessagesRelations = relations(scheduledMessages, ({ one }) => ({
  channel: one(chats, { fields: [scheduledMessages.channelId], references: [chats.id] }),
  author: one(users, { fields: [scheduledMessages.authorId], references: [users.id] }),
}))

export type DbScheduledMessage = typeof scheduledMessages.$inferSelect
export type DbNewScheduledMessage = typeof scheduledMessages.$inferInsert

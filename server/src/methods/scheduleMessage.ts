import { z } from 'zod'
import Elysia, { t } from 'elysia'
import { authenticate } from '@in/server/controllers/plugins'
import { TMakeApiResponse } from '@in/server/controllers/helpers'
import { db } from '@in/server/db'
import { scheduledMessages } from '@in/server/db/schema'

const createSchema = z.object({
  channelId: z.number(),
  body: z.string(),
  scheduledAt: z.string()
})

const response = TMakeApiResponse(t.Any())

export const scheduleMessageRoute = new Elysia({ tags: ['POST'] })
  .use(authenticate)
  .post(
    '/messages/schedule',
    async ({ body, store }) => {
      const input = createSchema.parse(body)
      const [row] = await db
        .insert(scheduledMessages)
        .values({
          channelId: input.channelId,
          authorId: store.currentUserId,
          body: input.body,
          scheduledAt: new Date(input.scheduledAt)
        })
        .returning()
      return { ok: true, result: row } as any
    },
    { body: t.Unknown(), response }
  )

import { Elysia } from "elysia"
import { setup } from "@in/server/setup"
import { handleError, makeApiRoute, makeUnauthApiRoute, makeUploadApiRoute } from "@in/server/controllers/helpers"
import {
  handler as sendEmailCodeHandler,
  Input as SendEmailCodeInput,
  Response as SendEmailCodeResponse,
} from "@in/server/methods/sendEmailCode"
import {
  handler as createSpaceHandler,
  Input as CreateSpaceInput,
  Response as CreateSpaceResponse,
} from "@in/server/methods/createSpace"
import {
  handler as getSpacesHandler,
  Input as GetSpacesInput,
  Response as GetSpacesResponse,
} from "@in/server/methods/getSpaces"
import {
  handler as getSpaceHandler,
  Input as GetSpaceInput,
  Response as GetSpaceResponse,
} from "@in/server/methods/getSpace"
import { handler as getMeHandler, Input as GetMeInput, Response as GetMeResponse } from "@in/server/methods/getMe"
import {
  handler as updateProfileHandler,
  Input as UpdateProfileInput,
  Response as UpdateProfileResponse,
} from "@in/server/methods/updateProfile"
import {
  handler as createThreadHandler,
  Input as CreateThreadInput,
  Response as CreateThreadResponse,
} from "@in/server/methods/createThread"
import {
  handler as verifyEmailCodeHandler,
  Input as VerifyEmailCodeInput,
  Response as VerifyEmailCodeResponse,
} from "@in/server/methods/verifyEmailCode"
import {
  handler as checkUsernameHandler,
  Input as CheckUsernameInput,
  Response as CheckUsernameResponse,
} from "@in/server/methods/checkUsername"
import {
  handler as sendSmsCodeHandler,
  Input as SendSmsCodeInput,
  Response as SendSmsCodeResponse,
} from "@in/server/methods/sendSmsCode"
import {
  handler as verifySmsCodeHandler,
  Input as VerifySmsCodeInput,
  Response as VerifySmsCodeResponse,
} from "@in/server/methods/verifySmsCode"
import {
  handler as getUserHandler,
  Input as GetUserInput,
  Response as GetUserResponse,
} from "@in/server/methods/getUser"
import {
  handler as searchContactsHandler,
  Input as SearchContactsInput,
  Response as SearchContactsResponse,
} from "@in/server/methods/searchContacts"
import {
  handler as getChatHistoryHandler,
  Input as GetChatHistoryInput,
  Response as GetChatHistoryResponse,
} from "@in/server/methods/getChatHistory"
import {
  handler as sendMessageHandler,
  Input as SendMessageInput,
  Response as SendMessageResponse,
} from "@in/server/methods/sendMessage"
import { scheduleMessageRoute } from "@in/server/methods/scheduleMessage"
import {
  handler as createPrivateChatHandler,
  Input as CreatePrivateChatInput,
  Response as CreatePrivateChatResponse,
} from "@in/server/methods/createPrivateChat"
import {
  handler as deleteSpaceHandler,
  Input as DeleteSpaceInput,
  Response as DeleteSpaceResponse,
} from "@in/server/methods/deleteSpace"
import {
  handler as leaveSpaceHandler,
  Input as LeaveSpaceInput,
  Response as LeaveSpaceResponse,
} from "@in/server/methods/leaveSpace"
import {
  handler as getPrivateChatsHandler,
  Input as GetPrivateChatsInput,
  Response as GetPrivateChatsResponse,
} from "@in/server/methods/getPrivateChats"
import {
  handler as getSpaceMembersHandler,
  Input as GetSpaceMembersInput,
  Response as GetSpaceMembersResponse,
} from "@in/server/methods/getSpaceMembers"
import {
  handler as getDialogsHandler,
  Input as GetDialogsInput,
  Response as GetDialogsResponse,
} from "@in/server/methods/getDialogs"

import {
  handler as savePushNotificationHandler,
  Input as SavePushNotificationInput,
  Response as SavePushNotificationResponse,
} from "@in/server/methods/savePushNotification"
import {
  handler as updateStatusHandler,
  Input as UpdateStatusInput,
  Response as UpdateStatusResponse,
} from "@in/server/methods/updateStatus"
import {
  handler as sendComposeActionHandler,
  Input as SendComposeActionInput,
  Response as SendComposeActionResponse,
} from "@in/server/methods/sendComposeAction"

import {
  handler as addReactionHandler,
  Input as AddReactionInput,
  Response as AddReactionResponse,
} from "@in/server/methods/addReaction"
import {
  handler as updateDialogHandler,
  Input as UpdateDialogInput,
  Response as UpdateDialogResponse,
} from "@in/server/methods/updateDialog"
import {
  handler as addMemberHandler,
  Input as AddMemberInput,
  Response as AddMemberResponse,
} from "@in/server/methods/addMember"
import { handler as logoutHandler, Input as LogoutInput, Response as LogoutResponse } from "@in/server/methods/logout"
import { uploadFileRoute } from "@in/server/methods/uploadFile"
import {
  handler as getDraftHandler,
  Input as GetDraftInput,
  Response as GetDraftResponse,
} from "@in/server/methods/getDraft"
import {
  handler as readMessagesHandler,
  Input as ReadMessagesInput,
  Response as ReadMessagesResponse,
} from "@in/server/methods/readMessages"
import {
  handler as updateProfilePhotoHandler,
  Input as UpdateProfilePhotoInput,
  Response as UpdateProfilePhotoResponse,
} from "@in/server/methods/updateProfilePhoto"

import {
  handler as deleteMessageHandler,
  Input as DeleteMessageInput,
  Response as DeleteMessageResponse,
} from "@in/server/methods/deleteMessage"

import {
  handler as createLinearIssueHandler,
  Input as CreateLinearIssueInput,
  Response as CreateLinearIssueResponse,
} from "@in/server/methods/createLinearIssue"

import {
  handler as getIntegrationsHandler,
  Input as GetIntegrationsInput,
  Response as GetIntegrationsResponse,
} from "@in/server/methods/getIntegrations"

import {
  handler as getAlphaTextHandler,
  Input as GetAlphaTextInput,
  Response as GetAlphaTextResponse,
} from "@in/server/methods/getAlphaText"

import {
  handler as sendMessage20250509Handler,
  Input as SendMessage20250509Input,
  Response as SendMessage20250509Response,
} from "@in/server/methods/sendMessage_20250509"

import {
  handler as getNotionDatabasesHandler,
  Input as GetNotionDatabasesInput,
  Response as GetNotionDatabasesResponse,
} from "@in/server/methods/notion/getNotionDatabases"

import {
  handler as saveNotionDatabaseIdHandler,
  Input as SaveNotionDatabaseIdInput,
  Response as SaveNotionDatabaseIdResponse,
} from "@in/server/methods/notion/saveNotionDatabaseId"

import {
  handler as createNotionTaskHandler,
  Input as CreateNotionTaskInput,
  Response as CreateNotionTaskResponse,
} from "@in/server/methods/notion/createNotionTask"

import {
  handler as deleteNotionTaskHandler,
  Input as DeleteNotionTaskInput,
  Response as DeleteNotionTaskResponse,
} from "@in/server/methods/notion/deleteNotionTask"

export const apiV1 = new Elysia({ name: "v1" })
  .group("v1", (app) => {
    return app
      .use(setup)
      .use(makeUnauthApiRoute("/sendSmsCode", SendSmsCodeInput, SendSmsCodeResponse, sendSmsCodeHandler))
      .use(makeUnauthApiRoute("/verifySmsCode", VerifySmsCodeInput, VerifySmsCodeResponse, verifySmsCodeHandler))
      .use(makeUnauthApiRoute("/sendEmailCode", SendEmailCodeInput, SendEmailCodeResponse, sendEmailCodeHandler))
      .use(
        makeUnauthApiRoute("/verifyEmailCode", VerifyEmailCodeInput, VerifyEmailCodeResponse, verifyEmailCodeHandler),
      )
      .use(makeApiRoute("/createSpace", CreateSpaceInput, CreateSpaceResponse, createSpaceHandler))
      .use(makeApiRoute("/updateProfile", UpdateProfileInput, UpdateProfileResponse, updateProfileHandler))
      .use(makeApiRoute("/getMe", GetMeInput, GetMeResponse, getMeHandler))
      .use(makeApiRoute("/getSpaces", GetSpacesInput, GetSpacesResponse, getSpacesHandler))
      .use(makeApiRoute("/getSpace", GetSpaceInput, GetSpaceResponse, getSpaceHandler))
      .use(makeApiRoute("/checkUsername", CheckUsernameInput, CheckUsernameResponse, checkUsernameHandler))
      .use(makeApiRoute("/createThread", CreateThreadInput, CreateThreadResponse, createThreadHandler))
      .use(makeApiRoute("/getUser", GetUserInput, GetUserResponse, getUserHandler))
      .use(makeApiRoute("/searchContacts", SearchContactsInput, SearchContactsResponse, searchContactsHandler))
      .use(makeApiRoute("/getChatHistory", GetChatHistoryInput, GetChatHistoryResponse, getChatHistoryHandler))
      .use(makeApiRoute("/sendMessage", SendMessageInput, SendMessageResponse, sendMessageHandler))
      .use(scheduleMessageRoute)
      .use(
        makeApiRoute("/createPrivateChat", CreatePrivateChatInput, CreatePrivateChatResponse, createPrivateChatHandler),
      )
      .use(makeApiRoute("/deleteSpace", DeleteSpaceInput, DeleteSpaceResponse, deleteSpaceHandler))
      .use(makeApiRoute("/leaveSpace", LeaveSpaceInput, LeaveSpaceResponse, leaveSpaceHandler))
      .use(makeApiRoute("/getPrivateChats", GetPrivateChatsInput, GetPrivateChatsResponse, getPrivateChatsHandler))
      .use(makeApiRoute("/getSpaceMembers", GetSpaceMembersInput, GetSpaceMembersResponse, getSpaceMembersHandler))
      .use(makeApiRoute("/getDialogs", GetDialogsInput, GetDialogsResponse, getDialogsHandler))
      .use(makeApiRoute("/updateStatus", UpdateStatusInput, UpdateStatusResponse, updateStatusHandler))
      .use(
        makeApiRoute("/sendComposeAction", SendComposeActionInput, SendComposeActionResponse, sendComposeActionHandler),
      )
      .use(
        makeApiRoute(
          "/savePushNotification",
          SavePushNotificationInput,
          SavePushNotificationResponse,
          savePushNotificationHandler,
        ),
      )
      .use(makeApiRoute("/addReaction", AddReactionInput, AddReactionResponse, addReactionHandler))
      .use(makeApiRoute("/updateDialog", UpdateDialogInput, UpdateDialogResponse, updateDialogHandler))
      .use(makeApiRoute("/addMember", AddMemberInput, AddMemberResponse, addMemberHandler))
      .use(makeApiRoute("/logout", LogoutInput, LogoutResponse, logoutHandler))
      .use(uploadFileRoute)
      .use(makeApiRoute("/getDraft", GetDraftInput, GetDraftResponse, getDraftHandler))
      .use(makeApiRoute("/readMessages", ReadMessagesInput, ReadMessagesResponse, readMessagesHandler))
      .use(
        makeApiRoute(
          "/updateProfilePhoto",
          UpdateProfilePhotoInput,
          UpdateProfilePhotoResponse,
          updateProfilePhotoHandler,
        ),
      )
      .use(
        makeApiRoute("/createLinearIssue", CreateLinearIssueInput, CreateLinearIssueResponse, createLinearIssueHandler),
      )
      .use(makeApiRoute("/deleteMessage", DeleteMessageInput, DeleteMessageResponse, deleteMessageHandler))
      .use(makeApiRoute("/getIntegrations", GetIntegrationsInput, GetIntegrationsResponse, getIntegrationsHandler))
      .use(makeApiRoute("/getAlphaText", GetAlphaTextInput, GetAlphaTextResponse, getAlphaTextHandler))
      .use(
        makeApiRoute(
          "/sendMessage20250509",
          SendMessage20250509Input,
          SendMessage20250509Response,
          sendMessage20250509Handler,
        ),
      )
      .use(
        makeApiRoute(
          "/getNotionDatabases",
          GetNotionDatabasesInput,
          GetNotionDatabasesResponse,
          getNotionDatabasesHandler,
        ),
      )
      .use(
        makeApiRoute(
          "/saveNotionDatabaseId",
          SaveNotionDatabaseIdInput,
          SaveNotionDatabaseIdResponse,
          saveNotionDatabaseIdHandler,
        ),
      )
      .use(makeApiRoute("/createNotionTask", CreateNotionTaskInput, CreateNotionTaskResponse, createNotionTaskHandler))
      .use(makeApiRoute("/deleteAttachment", DeleteNotionTaskInput, DeleteNotionTaskResponse, deleteNotionTaskHandler))
      .all("/*", () => {
        // fallback
        return { ok: false, errorCode: 404, description: "Method not found" }
      })
  })
  .use(handleError)

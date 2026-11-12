import type { components } from '@/shared/api/schema';

type Schemas = components['schemas'];

/** An in-app notification (named so it never clashes with the DOM `Notification`). */
export type AppNotification = Schemas['NotificationDTO'];

/** One channel preference for a category (group-specific rows carry `group_id`). */
export type NotificationPreference = Schemas['PreferenceDTO'];
export type NotificationPreferencePatch = Schemas['PreferencePatch'];
export type NotificationChannel = NotificationPreference['channel'];
/** Per-category email timing: `immediate`, or held for the summary email. */
export type DigestTiming = NotificationPreference['digest'];

/** Account-level summary email setting (GET/PATCH /me/preferences `email_digest`). */
export type EmailDigest = Schemas['PreferencesDTO']['email_digest'];

export type PushEndpointInput = Schemas['PushEndpointInput'];
/** A browser or device registered for push (never its endpoint URL or keys). */
export type PushEndpoint = Schemas['PushEndpointDTO'];
export type PushEndpointKind = PushEndpoint['kind'];
/** Whether this server can send Web Push, and the key browsers subscribe with. */
export type WebPushConfig = Schemas['WebPushConfig'];
export type UnreadCount = Schemas['UnreadCount'];
export type UnsubscribeResult = Schemas['UnsubscribeResult'];

/** Which notifications the center shows (all are newest first). */
export type NotificationView = 'inbox' | 'unread' | 'archived';

export interface NotificationFilters {
  view: NotificationView;
  /** A category name, or '' for every category. */
  category: string;
}

export interface NotificationPage {
  items: AppNotification[];
  /** Cursor for the next page; null on the last page. */
  nextCursor: string | null;
}

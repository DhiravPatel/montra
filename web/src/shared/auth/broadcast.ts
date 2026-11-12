/** Cross-tab auth notifications so every open tab reflects sign-in/out at once. */
export type AuthBroadcast = { type: 'signed-in' } | { type: 'signed-out' };

export interface AuthChannel {
  post: (message: AuthBroadcast) => void;
  close: () => void;
}

const CHANNEL_NAME = 'montra-auth';

function isAuthBroadcast(value: unknown): value is AuthBroadcast {
  if (typeof value !== 'object' || value === null || !('type' in value)) return false;
  return value.type === 'signed-in' || value.type === 'signed-out';
}

export function openAuthChannel(onMessage: (message: AuthBroadcast) => void): AuthChannel {
  if (typeof BroadcastChannel === 'undefined')
    return { post: () => undefined, close: () => undefined };
  const channel = new BroadcastChannel(CHANNEL_NAME);
  channel.onmessage = (event: MessageEvent<unknown>) => {
    if (isAuthBroadcast(event.data)) onMessage(event.data);
  };
  return {
    post: (message) => {
      channel.postMessage(message);
    },
    close: () => {
      channel.close();
    },
  };
}

import type { Message } from '../../types';

/** English `social` messages (source of truth for their keys). */
const messages = {
  // Round 4: friends (social graph, privacy by default)
  'social.title': 'Friends',
  'social.description':
    'Connect with people you trust to share budgets, goals and groups. Friends never see your transactions or balances.',
  'social.tabs.label': 'Friends sections',
  'social.tabs.friends': 'Friends',
  'social.tabs.requests': 'Requests',
  'social.tabs.waiting': { one: '{count} waiting', other: '{count} waiting' },
  'social.tabs.find': 'Find people',
  'social.tabs.blocked': 'Blocked & muted',
  'social.tabs.privacy': 'Privacy',
  'social.actionsFor': 'More actions for {name}',
  'social.username.calloutTitle': 'You don’t have a username yet',
  'social.username.calloutBody':
    'Friends find each other on Montra by exact username. Choose one so people you know can send you a request.',
  'social.username.calloutAction': 'Choose a username',
  'social.username.profileLink': 'View your profile',
  'social.username.title': 'Your username',
  'social.username.description':
    'Friends find you on Montra by your username. People you connect with see it next to your name.',
  'social.username.current': 'Your username is @{username}.',
  'social.username.none': 'You don’t have a username yet, so friends can’t find you.',
  'social.username.label': 'Username',
  'social.username.help': '3 to 30 characters: lowercase letters, numbers, dots and underscores.',
  'social.username.required': 'Enter a username.',
  'social.username.invalid':
    'Use 3 to 30 characters: lowercase letters, numbers, dots and underscores.',
  'social.username.taken': 'That username is taken. Try another one.',
  'social.username.reserved': 'That username is kept for Montra. Choose another one.',
  'social.username.unavailable': 'That username isn’t available. Try another one.',
  'social.username.unchanged': '@{username} is already your username',
  'social.username.saved': 'Your username is now @{username}',
  'social.username.savedFindable': 'Friends can find you by it.',
  'social.username.savedHidden':
    'You’re hidden from search right now. You can change that under “Who can find you”.',
  'social.username.change': 'Change username',
  'social.username.save': 'Save username',
  'social.friends.title': 'Your friends',
  'social.friends.description':
    'You can add friends to shared budgets, goals and groups. They never see your personal transactions or balances.',
  'social.friends.loading': 'Loading your friends…',
  'social.friends.error': 'We couldn’t load your friends',
  'social.friends.empty.title': 'No friends yet',
  'social.friends.empty.body':
    'Find people by their username and send them a request. Then you can share budgets, goals and groups with them.',
  'social.friends.empty.action': 'Find people',
  'social.friends.count': { one: '{count} friend', other: '{count} friends' },
  'social.remove.action': 'Remove',
  'social.remove.actionFor': 'Remove {name} from friends',
  'social.remove.title': 'Remove {name} from your friends?',
  'social.remove.body':
    'You’ll stop being friends, so you can’t add each other to new shared budgets or goals. Anything you already share, and groups you’re both in, stay as they are. Montra doesn’t tell them, and you can send a new request later.',
  'social.remove.confirm': 'Remove friend',
  'social.remove.done': 'Removed {name} from your friends',
  'social.remove.alreadyDone': 'You’re no longer friends with {name}',
  'social.block.action': 'Block',
  'social.block.title': 'Block {name}?',
  'social.block.effectFriends':
    'You’ll stop being friends, and any friend requests between you are cancelled.',
  'social.block.effectHidden':
    'You won’t see each other in friends, requests or search, and they can’t find you or send you requests.',
  'social.block.effectPrivate':
    'Montra doesn’t tell them. Groups you’re both in keep their shared history.',
  'social.block.confirm': 'Block',
  'social.block.done': '{name} is blocked',
  'social.block.notFound': 'We couldn’t find this person. Their account may have been closed.',
  'social.unblock.action': 'Unblock',
  'social.unblock.actionFor': 'Unblock {name}',
  'social.unblock.title': 'Unblock {name}?',
  'social.unblock.body':
    'They’ll be able to find you by username and send you friend requests again, if your privacy settings allow it. You won’t become friends again unless you both agree.',
  'social.unblock.confirm': 'Unblock',
  'social.unblock.done': '{name} is unblocked',
  'social.unblock.alreadyDone': '{name} isn’t blocked',
  'social.mute.action': 'Mute notifications',
  'social.unmute.action': 'Unmute notifications',
  'social.unmute.actionFor': 'Unmute notifications from {name}',
  'social.mute.done': 'Muted {name}',
  'social.mute.doneBody': 'You won’t get notifications from them. They aren’t told.',
  'social.unmute.done': 'Notifications from {name} are on again',
  'social.mute.failed': 'We couldn’t mute them',
  'social.unmute.failed': 'We couldn’t unmute them',
  'social.muted.badge': 'Muted',
  'social.requests.title': 'Friend requests',
  'social.requests.loading': 'Loading friend requests…',
  'social.requests.error': 'We couldn’t load your friend requests',
  'social.requests.incomingTitle': 'Requests for you',
  'social.requests.incomingDescription':
    'Accept to become friends. If you decline, Montra doesn’t notify them.',
  'social.requests.incomingEmpty': 'No requests waiting',
  'social.requests.incomingEmptyBody': 'When someone sends you a friend request, it shows up here.',
  'social.requests.outgoingTitle': 'Requests you sent',
  'social.requests.outgoingDescription':
    'Waiting for an answer. You can cancel a request at any time.',
  'social.requests.outgoingEmpty': 'You haven’t sent any requests',
  'social.requests.sentOn': 'Sent {date}',
  'social.requests.note': 'Note:',
  'social.requests.accept': 'Accept',
  'social.requests.acceptFrom': 'Accept request from {name}',
  'social.requests.decline': 'Decline',
  'social.requests.declineFrom': 'Decline request from {name}',
  'social.requests.cancel': 'Cancel request',
  'social.requests.cancelTo': 'Cancel request to {name}',
  'social.requests.accepted': 'You’re now friends with {name}',
  'social.requests.declined': 'Declined the request from {name}',
  'social.requests.cancelled': 'Cancelled your request to {name}',
  'social.requests.acceptFailed': 'We couldn’t accept the request',
  'social.requests.declineFailed': 'We couldn’t decline the request',
  'social.requests.cancelFailed': 'We couldn’t cancel the request',
  'social.requests.gone':
    'This request is no longer waiting. It may have been answered or cancelled.',
  'social.find.title': 'Find people by username',
  'social.find.description':
    'People are found only by their exact username: a partial username finds no one. Montra shows only people who chose to be findable, and never shows anyone’s money.',
  'social.find.label': 'Username',
  'social.find.help': 'Enter their exact username, like @asha_rao. Partial usernames find no one.',
  'social.find.submit': 'Search',
  'social.find.required': 'Enter a username.',
  'social.find.tooShort': {
    one: 'Enter the full username (at least {count} character).',
    other: 'Enter the full username (at least {count} characters).',
  },
  'social.find.invalid':
    'Usernames have 3 to 30 characters: lowercase letters, numbers, dots and underscores.',
  'social.find.searching': 'Searching…',
  'social.find.error': 'We couldn’t search right now',
  'social.find.foundAnnouncement': 'Found {name}, @{username}.',
  'social.find.notFoundTitle': 'No one found with the username @{username}',
  'social.find.notFoundBody':
    'Only the exact username finds someone, so check the spelling. Some people choose not to appear in search, and new accounts stay hidden until they turn it on.',
  'social.find.shareYours': 'You can also share your username, @{username}, so they can find you.',
  'social.find.self': 'That’s your own username',
  'social.find.selfBody':
    'Share it with people you know so they can find you and send you a request.',
  'social.find.resultLabel': 'Search result: {name}',
  'social.find.blockedNow': 'You blocked @{username}',
  'social.find.blockedNowBody':
    'They no longer appear in your search. You can unblock them under Blocked & muted.',
  'social.find.status.friend': 'Friends',
  'social.find.status.sent': 'Request sent',
  'social.find.status.received': 'Sent you a request',
  'social.find.status.self': 'You',
  'social.find.alreadyFriends': 'You and {name} are already friends.',
  'social.find.viewRequests': 'View requests',
  'social.send.note': 'Add a note',
  'social.send.noteHelp': 'They’ll see it with your request. Up to {max} characters.',
  'social.send.action': 'Send friend request',
  'social.send.actionTo': 'Send friend request to {name}',
  'social.send.done': 'Friend request sent to {name}',
  'social.send.doneBody': 'You’ll become friends when they accept.',
  'social.send.closed': '{name} isn’t accepting friend requests right now.',
  'social.send.notFound':
    'We couldn’t send a request to {name}. They may have changed their username or stopped being findable.',
  'social.send.conflict':
    'You’re already friends with {name}, or a request between you is already waiting.',
  'social.send.alreadyFriends': 'You and {name} are already friends.',
  'social.send.pending':
    'You already sent {name} a request. You’ll become friends when they accept.',
  'social.blocked.title': 'Blocked people',
  'social.blocked.description':
    'People you blocked disappear from your friends, requests and search, and they can’t find you or send you requests. They aren’t told.',
  'social.blocked.empty': 'You haven’t blocked anyone',
  'social.blocked.emptyBody':
    'To block someone, open the menu next to their name and choose Block.',
  'social.blocked.loading': 'Loading the people you blocked…',
  'social.blocked.error': 'We couldn’t load the people you blocked',
  'social.blocked.since': 'Blocked {date}',
  'social.blocked.loadMore': 'Show more blocked people',
  'social.loadMoreFailed': 'We couldn’t load more. Try again.',
  'social.muted.title': 'Muted people',
  'social.muted.description':
    'Muting stops notifications from someone, like friend requests. They aren’t told, and nothing else changes.',
  'social.muted.empty': 'You haven’t muted anyone',
  'social.muted.emptyBody':
    'To mute someone, open the menu next to their name and choose Mute notifications.',
  'social.muted.loading': 'Loading the people you muted…',
  'social.muted.error': 'We couldn’t load the people you muted',
  'social.muted.since': 'Muted {date}',
  'social.muted.loadMore': 'Show more muted people',
  'social.privacy.title': 'Who can find you',
  'social.privacy.description':
    'Choose who can find you and who can ask to be your friend. Changes apply as soon as you save.',
  'social.privacy.loading': 'Loading your privacy settings…',
  'social.privacy.error': 'We couldn’t load your privacy settings',
  'social.privacy.discoverable': 'Let people find me by my username',
  'social.privacy.discoverableHelp':
    'When on, people can find you by searching for your username, @{username}. When off, you don’t appear in search, but your friends and people in your groups can still add you.',
  'social.privacy.discoverableNoUsername':
    'You don’t have a username yet, so nobody can find you by search.',
  'social.privacy.hiddenByDefault':
    'New accounts start hidden: until you turn this on, nobody can find you by username, even if they know it.',
  'social.privacy.requests.legend': 'Who can send you friend requests',
  'social.privacy.requests.help': 'People you block can never send you requests.',
  'social.privacy.requests.everyone': 'Everyone',
  'social.privacy.requests.everyoneHelp': 'Anyone who finds you can send you a request.',
  'social.privacy.requests.friendsOfFriends': 'Friends of friends',
  'social.privacy.requests.friendsOfFriendsHelp': 'Only people who share a friend with you.',
  'social.privacy.requests.nobody': 'Nobody',
  'social.privacy.requests.nobodyHelp':
    'No one can send you requests. You can still send requests yourself.',
  'social.privacy.moneyNote':
    'Whatever you choose, friends never see your transactions or balances. Budgets and goals are shared only when you share them.',
  'social.privacy.save': 'Save privacy settings',
  'social.privacy.saved': 'Privacy settings saved',
} as const satisfies Record<string, Message>;

export default messages;

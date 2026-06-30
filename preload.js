/**
 * LuoguChat v8.0 — Preload Bridge
 * Secure contextBridge for renderer process
 */
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('bridge', {
  // Config
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (json) => ipcRenderer.invoke('save-config', json),

  // Login
  testLogin: (uid, cookie) => ipcRenderer.invoke('test-login', uid, cookie),
  autoLogin: () => ipcRenderer.invoke('auto-login'),
  hasSuperAllow: () => ipcRenderer.invoke('has-super-allow'),
  toggleIncognito: () => ipcRenderer.invoke('toggle-incognito'),
  isIncognito: () => ipcRenderer.invoke('is-incognito'),
  setCookieFormat: (uid, clientId) => ipcRenderer.invoke('set-cookie-format', uid, clientId),
  setCurrentMode: (mode) => ipcRenderer.invoke('set-current-mode', mode),

  // Chat
  refreshChatList: () => ipcRenderer.invoke('refresh-chat-list'),
  getChatList: () => ipcRenderer.invoke('get-chat-list'),
  getMessages: (uid, page, force) => ipcRenderer.invoke('get-messages', uid, page, force),
  sendMessage: (uid, content) => ipcRenderer.invoke('send-message', uid, content),
  deleteMessage: (msgId) => ipcRenderer.invoke('delete-message', msgId),

  // Search
  searchUsers: (keyword) => ipcRenderer.invoke('search-users', keyword),

  // Avatars
  getAvatarPath: (uid) => ipcRenderer.invoke('get-avatar-path', uid),
  requestAvatar: (uid) => ipcRenderer.invoke('request-avatar', uid),
  prefetchAvatars: (uidListJson) => ipcRenderer.invoke('prefetch-avatars', uidListJson),

  // Server
  syncNow: () => ipcRenderer.invoke('sync-now'),
  getServerStatus: () => ipcRenderer.invoke('get-server-status'),
  recordAIUse: (count) => ipcRenderer.invoke('record-ai-use', count),

  // System fonts
  getSystemFonts: () => ipcRenderer.invoke('get-system-fonts'),

  // Clipboard
  copyText: (text) => ipcRenderer.invoke('copy-text', text),

  // Sound
  playSound: (filePath) => ipcRenderer.invoke('play-sound', filePath),

  // Window controls
  minimizeWindow: () => ipcRenderer.invoke('minimize-window'),
  maximizeWindow: () => ipcRenderer.invoke('maximize-window'),
  closeWindow: () => ipcRenderer.invoke('close-window'),
  isMaximized: () => ipcRenderer.invoke('is-maximized'),
  snapLeft: () => ipcRenderer.invoke('snap-left'),
  snapRight: () => ipcRenderer.invoke('snap-right'),
  snapUp: () => ipcRenderer.invoke('snap-up'),
  snapDown: () => ipcRenderer.invoke('snap-down'),

  // External
  openExternal: (url) => ipcRenderer.invoke('open-external'),
  getAppPath: () => ipcRenderer.invoke('get-app-path'),
  openChatWindow: (uid, name) => ipcRenderer.invoke('open-chat-window', uid, name),
  openSettingsWindow: () => ipcRenderer.invoke('open-settings-window'),
  openAISettingsWindow: () => ipcRenderer.invoke('open-ai-settings-window'),

  // Popup notification actions
  popupFocusChat: (uid, name) => ipcRenderer.invoke('popup-focus-chat', uid, name),
  popupOpenChatWin: (uid, name) => ipcRenderer.invoke('popup-open-chat-win', uid, name),
  popupSendReply: (uid, content) => ipcRenderer.invoke('popup-send-reply', uid, content),

  // Events from main process
  onNewMessage: (cb) => {
    ipcRenderer.on('new-message', (e, ...args) => cb(...args));
  },
  onImportantMessage: (cb) => {
    ipcRenderer.on('important-message', (e, ...args) => cb(...args));
  },
  onWsStatus: (cb) => {
    ipcRenderer.on('ws-status', (e, status) => cb(status));
  },
  onAvatarReady: (cb) => {
    ipcRenderer.on('avatar-ready', (e, uid, path) => cb(uid, path));
  },
  onAutoReplyDone: (cb) => {
    ipcRenderer.on('auto-reply-done', (e, ...args) => cb(...args));
  },
  onReplySent: (cb) => {
    ipcRenderer.on('reply-sent', (e, ...args) => cb(...args));
  },
  onServerStatus: (cb) => {
    ipcRenderer.on('server-status', (e, status) => cb(status));
  },
  onAutoLogin: (cb) => {
    ipcRenderer.on('auto-login', (e, uid) => cb(uid));
  },
  onChatWindowOpen: (cb) => {
    ipcRenderer.on('chat-window-open', (e, uid, name) => cb(uid, name));
  },
  onConfigUpdated: (cb) => {
    ipcRenderer.on('config-updated', () => cb());
  },
  onMessagesUpdated: (cb) => {
    ipcRenderer.on('messages-updated', (e, uid, page, json) => cb(uid, page, json));
  },
  onFocusChatUser: (cb) => {
    ipcRenderer.on('focus-chat-user', (e, uid, name) => cb(uid, name));
  },
  onOpenChatWinFromPopup: (cb) => {
    ipcRenderer.on('open-chat-window-from-popup', (e, uid, name) => cb(uid, name));
  },

  // Remove listeners
  removeAllListeners: (channel) => {
    ipcRenderer.removeAllListeners(channel);
  }
});

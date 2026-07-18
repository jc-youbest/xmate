// MailboxSidebarOutputIntent
//
// Typed requests that leave Library's mailbox sidebar. App owns workspace
// presentation; Library never resizes or calls Editor directly.

enum MailboxSidebarOutputIntent: Equatable {
    case closeSidebar
}

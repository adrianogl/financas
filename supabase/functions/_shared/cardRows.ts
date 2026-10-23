import {
  BANK_ACCOUNT_TYPE,
  BANK_CODE_LENGTH,
  BANK_NAMES,
  FIRST_SYNC_MONTHS,
  HEALTHY_ITEM_STATUSES,
  NEEDS_RECONNECT_ITEM_STATUSES,
  NICKNAME_SEPARATOR,
  SYNC_OVERLAP_DAYS,
} from "./cardConstants.ts"
import type {
  CardAccountRow,
  CardTransactionRow,
  ConnectionStatus,
  DateWindow,
  PluggyAccount,
  PluggyItem,
  PluggyTransaction,
} from "./pluggyTypes.ts"

export function transactionRow(tx: PluggyTransaction, cardAccountId: string): Omit<CardTransactionRow, "user_id"> {
  const metadata = tx.creditCardMetadata
  const value = tx.amountInAccountCurrency ?? tx.amount
  return {
    id: tx.id,
    card_account_id: cardAccountId,
    date: tx.date.slice(0, 10),
    description: tx.description ?? "Sem descrição",
    amount: Math.abs(value),
    type: tx.type,
    is_pending: tx.status === "PENDING",
    installment_number: metadata?.installmentNumber ?? null,
    total_installments: metadata?.totalInstallments ?? null,
    purchase_date: metadata?.purchaseDate ? metadata.purchaseDate.slice(0, 10) : null,
  }
}

function titleCase(text: string): string {
  return text
    .toLowerCase()
    .split(/[\s_]+/)
    .filter(Boolean)
    .map((word) => word[0].toUpperCase() + word.slice(1))
    .join(" ")
}

export function institutionName(accounts: PluggyAccount[]): string | null {
  for (const account of accounts) {
    if (account.type !== BANK_ACCOUNT_TYPE) continue
    const transferNumber = account.bankData?.transferNumber
    if (!transferNumber) continue
    const code = transferNumber.trim().slice(0, BANK_CODE_LENGTH)
    return BANK_NAMES[code] ?? (account.name.trim() || null)
  }
  return null
}

export function brandLabel(account: PluggyAccount): string | null {
  const parts = [account.creditData?.brand, account.creditData?.level]
    .map((part) => (part ?? "").trim())
    .filter(Boolean)
    .map(titleCase)
  return parts.length > 0 ? parts.join(" ") : null
}

export function legacyNickname(account: PluggyAccount): string {
  return `${account.name.trim()}${NICKNAME_SEPARATOR}${account.number}`
}

export function defaultNickname(account: PluggyAccount, institution: string | null): string {
  return institution ?? legacyNickname(account)
}

export function accountRow(
  account: PluggyAccount,
  connectionId: string,
  institution: string | null,
  existingNickname?: string,
): CardAccountRow {
  const keepsExisting = existingNickname !== undefined && existingNickname !== legacyNickname(account)
  return {
    connection_id: connectionId,
    pluggy_account_id: account.id,
    name: account.name.trim(),
    last_digits: account.number,
    nickname: keepsExisting ? existingNickname : defaultNickname(account, institution),
    brand_label: brandLabel(account),
  }
}

export function connectionStatus(item: Pick<PluggyItem, "status">): ConnectionStatus {
  if (NEEDS_RECONNECT_ITEM_STATUSES.includes(item.status)) return "needs_reconnect"
  if (HEALTHY_ITEM_STATUSES.includes(item.status)) return "active"
  return "error"
}

function shiftDate(isoDate: string, shift: (d: Date) => void): string {
  const date = new Date(`${isoDate}T00:00:00Z`)
  shift(date)
  return date.toISOString().slice(0, 10)
}

export function syncWindow(lastSyncedAt: string | null, today: string): DateWindow {
  if (!lastSyncedAt) {
    return { from: shiftDate(today, (d) => d.setUTCMonth(d.getUTCMonth() - FIRST_SYNC_MONTHS)), to: today }
  }
  return {
    from: shiftDate(lastSyncedAt.slice(0, 10), (d) => d.setUTCDate(d.getUTCDate() - SYNC_OVERLAP_DAYS)),
    to: today,
  }
}

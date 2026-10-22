import {
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

export function accountRow(account: PluggyAccount, connectionId: string, existingNickname?: string): CardAccountRow {
  const name = account.name.trim()
  return {
    connection_id: connectionId,
    pluggy_account_id: account.id,
    name,
    last_digits: account.number,
    nickname: existingNickname ?? `${name}${NICKNAME_SEPARATOR}${account.number}`,
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

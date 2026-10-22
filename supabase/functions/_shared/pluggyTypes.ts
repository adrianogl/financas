export type PluggyCreditCardMetadata = {
  installmentNumber?: number | null
  totalInstallments?: number | null
  purchaseDate?: string | null
}

export type PluggyTransaction = {
  id: string
  description: string | null
  amount: number
  amountInAccountCurrency?: number | null
  currencyCode: string
  date: string
  type: "DEBIT" | "CREDIT"
  status: "POSTED" | "PENDING"
  creditCardMetadata?: PluggyCreditCardMetadata | null
}

export type PluggyAccount = {
  id: string
  name: string
  number: string
  type: string
}

export type PluggyItem = {
  id: string
  status: string
  clientUserId?: string | null
  connector?: { id: number; name: string }
}

export type ConnectionStatus = "active" | "needs_reconnect" | "error"

export type CardTransactionRow = {
  id: string
  user_id: string
  card_account_id: string
  date: string
  description: string
  amount: number
  type: "DEBIT" | "CREDIT"
  is_pending: boolean
  installment_number: number | null
  total_installments: number | null
  purchase_date: string | null
}

export type CardAccountRow = {
  connection_id: string
  pluggy_account_id: string
  name: string
  last_digits: string
  nickname: string
}

export type DateWindow = { from: string; to: string }

export type SyncFilter = { userId?: string; connectionIds?: string[] }

export type ConnectionSyncResult = {
  connectionId: string
  ok: boolean
  error?: string
}

export type ConnectTokenBody = { itemId?: string; options: { clientUserId: string } }

export type CardsConnectRequest =
  | { action: "token"; itemId?: string | null }
  | { action: "register"; itemId: string }
  | { action: "remove"; connectionId: string }

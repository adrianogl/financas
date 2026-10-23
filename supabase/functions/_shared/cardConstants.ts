export const PLUGGY_API = "https://api.pluggy.ai"
export const API_KEY_TTL_MS = 100 * 60 * 1000
export const FIRST_SYNC_MONTHS = 12
export const SYNC_OVERLAP_DAYS = 7
export const NEEDS_RECONNECT_ITEM_STATUSES = ["LOGIN_ERROR", "WAITING_USER_INPUT"]
export const HEALTHY_ITEM_STATUSES = ["UPDATED", "UPDATING"]
export const CREDIT_ACCOUNT_TYPE = "CREDIT"
export const BANK_ACCOUNT_TYPE = "BANK"
export const BANK_CODE_LENGTH = 3
export const BANK_NAMES: Record<string, string> = {
  "001": "Banco do Brasil",
  "033": "Santander",
  "077": "Inter",
  "104": "Caixa",
  "208": "BTG",
  "212": "Original",
  "237": "Bradesco",
  "260": "Nubank",
  "290": "PagBank",
  "323": "Mercado Pago",
  "336": "C6",
  "341": "Itaú",
  "380": "PicPay",
  "655": "Neon",
  "748": "Sicredi",
  "756": "Sicoob",
}
export const NICKNAME_SEPARATOR = " ····"
export const UPSERT_CHUNK_SIZE = 500
export const CRON_SECRET_HEADER = "x-cron-secret"
export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

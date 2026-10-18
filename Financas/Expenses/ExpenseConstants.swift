enum ExpenseConstants {
    static let expensesTable = "expenses"
    static let termsTable = "expense_terms"
    static let billsTable = "expense_bills"
    static let partsTable = "expense_parts"
    static let partTermsTable = "expense_part_terms"
    static let partBillsTable = "expense_part_bills"
    static let entriesTable = "expense_entries"
    static let spendingHistoryMonths = 6
    static let loadFailedMessage = "Não foi possível carregar suas despesas. Tente de novo."
    static let entryAmountMessage = "Informe um valor maior que zero."
    static let entryDateMessage = "Escolha uma data dentro do período da despesa."
    static let partsFooter = "Sem partes, a despesa tem um valor só. Com partes, o valor previsto é a soma delas."
    static let spendingFooter = "Gasto do mês não tem vencimento nem aviso. Você adiciona os gastos ao longo do mês, e eles já contam como pagos."
    static let billKindTitle = "Conta com vencimento"
    static let spendingKindTitle = "Gasto do mês"
}

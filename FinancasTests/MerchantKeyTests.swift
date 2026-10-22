import Testing
@testable import Financas

struct MerchantKeyTests {
    @Test func merchantKeyStripsInstallmentAndPunctuation() {
        #expect(MerchantKey.make("MAGALU PARC 03/10") == "MAGALU")
        #expect(MerchantKey.make("EBN    *PLAYSTATION    CURITIB") == "EBN PLAYSTATION CURITIB")
        #expect(MerchantKey.make("Açaí da Esquina") == "ACAI DA ESQUINA")
        #expect(MerchantKey.make("WELLHUB ADRIANO GONCAL SAO PAULO BRA") != MerchantKey.make("WELLHUB CRISTIANO GONC SAO PAULO BRA"))
    }
}

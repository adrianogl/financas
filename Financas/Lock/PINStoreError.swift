import Security

enum PINStoreError: Error, Equatable {
    case randomBytesUnavailable
    case keychain(OSStatus)

    var message: String {
        "Não foi possível salvar o PIN. Tente de novo."
    }
}

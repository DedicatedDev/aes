import Foundation
import CryptoSwift

fileprivate func evpKDF(passphrase: String, salt: [UInt8], keySize: Int, ivSize: Int, iterations: Int) -> (key: [UInt8], iv: [UInt8]) {
    var derivedBytes = [UInt8]()
    var block: [UInt8] = []

    let data = passphrase.data(using: .utf8)!
    let pass = Array(data)

    while derivedBytes.count < (keySize + ivSize) {
        if !block.isEmpty {
            block += pass + salt
        } else {
            block = pass + salt
        }

        for _ in 1...iterations {
            block = try! HMAC(key: block, variant: .sha2(.sha256)).authenticate(block)
        }

        derivedBytes += block
        block.removeAll()
    }

    let key = Array(derivedBytes[0..<keySize])
    let iv = Array(derivedBytes[keySize..<(keySize + ivSize)])

    return (key: key, iv: iv)
}

public func encryptAES(plainText: String, passphrase: String) -> String? {
    var salt = Data(count: 8)
    let result = salt.withUnsafeMutableBytes { bytes -> Int32 in
        SecRandomCopyBytes(kSecRandomDefault, 8, bytes.baseAddress!)
    }
    guard result == errSecSuccess else {
        print("Error generating random bytes")
        return nil
    }

    let keySize = 16
    let ivSize = 16
    let iterations = 1000

    let (key, iv) = evpKDF(passphrase: passphrase, salt: salt.bytes, keySize: keySize, ivSize: ivSize, iterations: iterations)

    guard let plainTextData = plainText.data(using: .utf8) else {
        return nil
    }

    do {
        let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
        let encryptedBytes = try aes.encrypt(plainTextData.bytes)

        let header = "Salted__".data(using: .utf8)! + salt
        let encryptedData = Data(header.bytes + encryptedBytes)
        return encryptedData.base64EncodedString()
    } catch {
        print("Error encrypting data: \(error)")
        return nil
    }
}

public func decryptAES(cipherText: String, passphrase: String) -> String? {
    guard let encryptedData = Data(base64Encoded: cipherText,options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) else {
        return nil
    }


    let salt = encryptedData.subdata(in: 8..<16)

    let keySize = 16
    let ivSize = 16
    let iterations = 1000

    let (key, iv) = evpKDF(passphrase: passphrase, salt: salt.bytes, keySize: keySize, ivSize: ivSize, iterations: iterations)

    let encryptedBytes = encryptedData.subdata(in: 16..<encryptedData.count).bytes

    do {
        let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
        let decryptedBytes = try aes.decrypt(encryptedBytes)
        return String(bytes: decryptedBytes, encoding: .utf8)
    } catch {
        print("Error decrypting data: \(error)")
        return nil
    }
}

import AnyCodable
import Foundation
@testable import PortalSwift

extension GetTransactionDetailsResponse {
  static func stub(
    data: TransactionLookupResponse = .stubEmpty(),
    metadata: GetTransactionDetailsMetadata = .stub()
  ) -> GetTransactionDetailsResponse {
    return GetTransactionDetailsResponse(data: data, metadata: metadata)
  }
}

extension GetTransactionDetailsMetadata {
  static func stub(
    chainId: String = "eip155:10143",
    signature: String = "0xabc123"
  ) -> GetTransactionDetailsMetadata {
    return GetTransactionDetailsMetadata(chainId: chainId, signature: signature)
  }
}

extension TransactionLookupResponse {
  static func stubEmpty() -> TransactionLookupResponse {
    return TransactionLookupResponse(
      evmTransaction: nil,
      evmUserOperation: nil,
      solanaTransaction: nil,
      bitcoinTransaction: nil,
      stellarTransaction: nil,
      tronTransaction: nil
    )
  }

  static func stubEvmTransaction(
    _ tx: EvmTransactionLookupResult = .stub()
  ) -> TransactionLookupResponse {
    return TransactionLookupResponse(
      evmTransaction: tx,
      evmUserOperation: nil,
      solanaTransaction: nil,
      bitcoinTransaction: nil,
      stellarTransaction: nil,
      tronTransaction: nil
    )
  }

  static func stubEvmUserOperation(
    _ op: EvmUserOperationLookupResult = .stub()
  ) -> TransactionLookupResponse {
    return TransactionLookupResponse(
      evmTransaction: nil,
      evmUserOperation: op,
      solanaTransaction: nil,
      bitcoinTransaction: nil,
      stellarTransaction: nil,
      tronTransaction: nil
    )
  }

  static func stubSolanaTransaction(
    _ tx: SolanaTransactionLookupResult = .stub()
  ) -> TransactionLookupResponse {
    return TransactionLookupResponse(
      evmTransaction: nil,
      evmUserOperation: nil,
      solanaTransaction: tx,
      bitcoinTransaction: nil,
      stellarTransaction: nil,
      tronTransaction: nil
    )
  }

  static func stubBitcoinTransaction(
    _ tx: BitcoinTransactionLookupResult = .stub()
  ) -> TransactionLookupResponse {
    return TransactionLookupResponse(
      evmTransaction: nil,
      evmUserOperation: nil,
      solanaTransaction: nil,
      bitcoinTransaction: tx,
      stellarTransaction: nil,
      tronTransaction: nil
    )
  }

  static func stubStellarTransaction(
    _ tx: StellarTransactionLookupResult = .stub()
  ) -> TransactionLookupResponse {
    return TransactionLookupResponse(
      evmTransaction: nil,
      evmUserOperation: nil,
      solanaTransaction: nil,
      bitcoinTransaction: nil,
      stellarTransaction: tx,
      tronTransaction: nil
    )
  }

  static func stubTronTransaction(
    _ tx: TronTransactionLookupResult = .stub()
  ) -> TransactionLookupResponse {
    return TransactionLookupResponse(
      evmTransaction: nil,
      evmUserOperation: nil,
      solanaTransaction: nil,
      bitcoinTransaction: nil,
      stellarTransaction: nil,
      tronTransaction: tx
    )
  }
}

extension EvmTransactionLookupResult {
  static func stub(
    hash: String = "0x7a2ddf10",
    from: String = "0x4337003f",
    to: String? = "0x5ff137d4",
    value: String = "0x0",
    nonce: String = "0x162e",
    blockNumber: String? = "0x11804a5",
    blockHash: String? = "0x1d918839",
    transactionIndex: String? = "0x4",
    gas: String = "0xbe974",
    gasPrice: String? = "0x17dd79e100",
    maxFeePerGas: String? = "0x2381b55500",
    maxPriorityFeePerGas: String? = "0x9502f900",
    input: String = "0x1fad948c",
    type: String = "0x2",
    status: String? = "0x1",
    gasUsed: String? = "0xbe974",
    effectiveGasPrice: String? = "0x17dd79e100",
    logs: [EvmTransactionLookupLog]? = [.stub()],
    contractAddress: String? = nil
  ) -> EvmTransactionLookupResult {
    return EvmTransactionLookupResult(
      hash: hash, from: from, to: to, value: value, nonce: nonce,
      blockNumber: blockNumber, blockHash: blockHash, transactionIndex: transactionIndex,
      gas: gas, gasPrice: gasPrice, maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas, input: input, type: type,
      status: status, gasUsed: gasUsed, effectiveGasPrice: effectiveGasPrice,
      logs: logs, contractAddress: contractAddress
    )
  }
}

extension EvmTransactionLookupLog {
  static func stub(
    address: String = "0x534b2f3a",
    topics: [String] = ["0xddf252ad"],
    data: String = "0x00000000",
    blockNumber: String = "0x11804a5",
    transactionHash: String = "0x7a2ddf10",
    logIndex: String = "0x9"
  ) -> EvmTransactionLookupLog {
    return EvmTransactionLookupLog(
      address: address, topics: topics, data: data,
      blockNumber: blockNumber, transactionHash: transactionHash, logIndex: logIndex
    )
  }
}

extension EvmUserOperationLookupResult {
  static func stub(
    sender: String = "0xe9791af5",
    nonce: String = "0x1",
    callData: String = "0x51945447",
    callGasLimit: String = "0x2a2d8",
    verificationGasLimit: String = "0x405bf",
    preVerificationGas: String = "0x81bc7",
    maxFeePerGas: String = "0x2548319940",
    maxPriorityFeePerGas: String = "0x9c765240",
    signature: String = "0x00000000cf3e",
    entryPoint: String = "0x5FF137D4",
    success: Bool? = true,
    actualGasCost: String? = "0x10fadccba5a4700",
    actualGasUsed: String? = "0xb5ebc",
    receipt: EvmTransactionLookupResult? = .stub()
  ) -> EvmUserOperationLookupResult {
    return EvmUserOperationLookupResult(
      sender: sender, nonce: nonce, callData: callData,
      callGasLimit: callGasLimit, verificationGasLimit: verificationGasLimit,
      preVerificationGas: preVerificationGas, maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas, signature: signature,
      entryPoint: entryPoint, success: success, actualGasCost: actualGasCost,
      actualGasUsed: actualGasUsed, receipt: receipt
    )
  }
}

extension SolanaTransactionLookupResult {
  static func stub(
    blockTime: Int? = 1747834869,
    error: String? = nil,
    signature: String = "4U9JaGKb86",
    status: String = "finalized",
    transactionDetails: SolanaTransactionDetailsInner? = nil
  ) -> SolanaTransactionLookupResult {
    return SolanaTransactionLookupResult(
      blockTime: blockTime, error: error, signature: signature,
      status: status, transactionDetails: transactionDetails
    )
  }
}

extension BitcoinTransactionLookupResult {
  static func stub(
    txid: String = "cb56ab9f",
    version: Int = 2,
    size: Int = 222,
    weight: Int = 561,
    locktime: Int = 0,
    fee: Int = 280,
    status: BitcoinTransactionLookupStatus = .stub(),
    vin: [BitcoinLookupVin] = [.stub()],
    vout: [BitcoinLookupVout] = [.stub()]
  ) -> BitcoinTransactionLookupResult {
    return BitcoinTransactionLookupResult(
      txid: txid, version: version, size: size, weight: weight,
      locktime: locktime, fee: fee, status: status, vin: vin, vout: vout
    )
  }
}

extension BitcoinTransactionLookupStatus {
  static func stub(
    confirmed: Bool = true,
    blockHeight: Int? = 4814068,
    blockHash: String? = nil,
    blockTime: Int? = 1768583503
  ) -> BitcoinTransactionLookupStatus {
    return BitcoinTransactionLookupStatus(
      confirmed: confirmed, blockHeight: blockHeight,
      blockHash: blockHash, blockTime: blockTime
    )
  }
}

extension BitcoinLookupVin {
  static func stub(
    txid: String = "1451fd4b",
    vout: Int = 1,
    prevout: BitcoinLookupPrevout? = .stub(),
    scriptsig: String = "",
    witness: [String] = [],
    sequence: UInt = 4294967295
  ) -> BitcoinLookupVin {
    return BitcoinLookupVin(
      txid: txid, vout: vout, prevout: prevout,
      scriptsig: scriptsig, witness: witness, sequence: sequence
    )
  }
}

extension BitcoinLookupPrevout {
  static func stub(
    scriptpubkey: String = "0014b425cc06",
    scriptpubkeyAddress: String = "tb1qksjucp5al0l38",
    value: Int = 10000
  ) -> BitcoinLookupPrevout {
    return BitcoinLookupPrevout(
      scriptpubkey: scriptpubkey, scriptpubkeyAddress: scriptpubkeyAddress, value: value
    )
  }
}

extension BitcoinLookupVout {
  static func stub(
    scriptpubkey: String = "0014b425cc06",
    scriptpubkeyAddress: String = "tb1qksjucp5al0l38",
    value: Int = 10000
  ) -> BitcoinLookupVout {
    return BitcoinLookupVout(
      scriptpubkey: scriptpubkey, scriptpubkeyAddress: scriptpubkeyAddress, value: value
    )
  }
}

extension StellarTransactionLookupResult {
  static func stub(
    id: String = "c21b3ba7",
    hash: String = "c21b3ba7",
    ledger: Int = 1586182,
    createdAt: String = "2026-03-19T14:56:39Z",
    sourceAccount: String = "GC7W7UECSSCQFFCM3RYSBO247KIAEQNFBKPUAFMB436X3LWWXR7PF2UM",
    feeCharged: String = "100",
    maxFee: String = "10000",
    operationCount: Int = 1,
    successful: Bool = true,
    memo: String? = nil,
    memoType: String = "none",
    operations: [AnyCodable] = []
  ) -> StellarTransactionLookupResult {
    return StellarTransactionLookupResult(
      id: id, hash: hash, ledger: ledger, createdAt: createdAt,
      sourceAccount: sourceAccount, feeCharged: feeCharged, maxFee: maxFee,
      operationCount: operationCount, successful: successful, memo: memo,
      memoType: memoType, operations: operations
    )
  }
}

extension TronTransactionLookupResult {
  static func stub(
    txID: String = "74ffe63b",
    blockNumber: Int? = 55205096,
    blockTimeStamp: Int64? = 1741808940000,
    contractResult: [String] = ["SUCCESS"],
    receipt: TronTransactionLookupReceipt? = .stub(),
    contractType: String? = "TriggerSmartContract",
    contractData: AnyCodable? = AnyCodable(["data": "a9059cbb"]),
    result: String? = "SUCCESS"
  ) -> TronTransactionLookupResult {
    return TronTransactionLookupResult(
      txID: txID, blockNumber: blockNumber, blockTimeStamp: blockTimeStamp,
      contractResult: contractResult, receipt: receipt, contractType: contractType,
      contractData: contractData, result: result
    )
  }
}

extension TronTransactionLookupReceipt {
  static func stub(
    result: String? = "SUCCESS",
    energyUsage: Int? = nil,
    energyUsageTotal: Int? = 29650,
    netUsage: Int? = 344
  ) -> TronTransactionLookupReceipt {
    return TronTransactionLookupReceipt(
      result: result, energyUsage: energyUsage,
      energyUsageTotal: energyUsageTotal, netUsage: netUsage
    )
  }
}

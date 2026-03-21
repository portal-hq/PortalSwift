import AnyCodable
@testable import PortalSwift
import XCTest

final class GetTransactionDetailsTests: XCTestCase {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  var api: PortalApi?

  override func setUpWithError() throws {
    api = PortalApi(apiKey: MockConstants.mockApiKey, apiHost: MockConstants.mockHost, requests: MockPortalRequests())
  }

  override func tearDownWithError() throws {
    api = nil
  }

  func initPortalApiWith(
    apiHost: String = MockConstants.mockHost,
    requests: PortalRequestsProtocol = MockPortalRequests()
  ) {
    self.api = PortalApi(apiKey: MockConstants.mockApiKey, apiHost: apiHost, requests: requests)
  }
}

// MARK: - API call tests

extension GetTransactionDetailsTests {
  func test_getTransactionDetails_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let response = GetTransactionDetailsResponse.stub(data: .stubEvmTransaction())
    portalRequestsSpy.returnData = try encoder.encode(response)
    initPortalApiWith(requests: portalRequestsSpy)

    // when
    _ = try await api?.getTransactionDetails(chain: "monad-testnet", signature: "0xabc")

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_getTransactionDetails_willCall_executeRequest_withCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let response = GetTransactionDetailsResponse.stub(data: .stubEvmTransaction())
    portalRequestsSpy.returnData = try encoder.encode(response)
    initPortalApiWith(requests: portalRequestsSpy)

    // when
    _ = try await api?.getTransactionDetails(chain: "monad-testnet", signature: "0xabc123")

    // then
    XCTAssertEqual(
      portalRequestsSpy.executeRequestParam?.url.path(),
      "/api/v3/clients/me/chains/monad-testnet/transactions/0xabc123"
    )
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
  }

  @available(iOS 16.0, *)
  func test_getTransactionDetails_willPercentEncode_chainWithColon() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let response = GetTransactionDetailsResponse.stub(data: .stubTronTransaction())
    portalRequestsSpy.returnData = try encoder.encode(response)
    initPortalApiWith(requests: portalRequestsSpy)

    // when
    _ = try await api?.getTransactionDetails(chain: "tron:nile", signature: "74ffe63b")

    // then
    let urlPath = portalRequestsSpy.executeRequestParam?.url.absoluteString ?? ""
    XCTAssertTrue(urlPath.contains("tron%3Anile") || urlPath.contains("tron:nile"))
    XCTAssertTrue(urlPath.contains("/transactions/74ffe63b"))
  }

  @available(iOS 16.0, *)
  func test_getTransactionDetails_willPercentEncode_bitcoinChainId() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let response = GetTransactionDetailsResponse.stub(data: .stubBitcoinTransaction())
    portalRequestsSpy.returnData = try encoder.encode(response)
    initPortalApiWith(requests: portalRequestsSpy)

    // when
    _ = try await api?.getTransactionDetails(
      chain: "bip122:000000000933ea01ad0ee984209779ba-p2wpkh",
      signature: "cb56ab9f"
    )

    // then
    let urlString = portalRequestsSpy.executeRequestParam?.url.absoluteString ?? ""
    XCTAssertTrue(urlString.contains("bip122"))
    XCTAssertTrue(urlString.contains("/transactions/cb56ab9f"))
  }

  func test_getTransactionDetails_willPassBearerToken() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let response = GetTransactionDetailsResponse.stub(data: .stubEvmTransaction())
    portalRequestsSpy.returnData = try encoder.encode(response)
    initPortalApiWith(requests: portalRequestsSpy)

    // when
    _ = try await api?.getTransactionDetails(chain: "monad-testnet", signature: "0xabc")

    // then
    let headers = portalRequestsSpy.executeRequestParam?.headers ?? [:]
    XCTAssertEqual(headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
  }

  func test_getTransactionDetails_willThrowError_whenRequestFails() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    // when / then
    do {
      _ = try await api?.getTransactionDetails(chain: "monad-testnet", signature: "0xabc")
      XCTFail("Expected an error to be thrown")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, portalRequestsFailMock.errorToThrow.code)
    }
  }
}

// MARK: - EVM Transaction decoding tests

extension GetTransactionDetailsTests {
  func test_decode_evmTransaction_fromFullJSON() throws {
    let json = """
    {
      "data": {
        "evmTransaction": {
          "hash": "0x7a2ddf10",
          "from": "0x4337003f",
          "to": "0x5ff137d4",
          "value": "0x0",
          "nonce": "0x162e",
          "blockNumber": "0x11804a5",
          "blockHash": "0x1d918839",
          "transactionIndex": "0x4",
          "gas": "0xbe974",
          "gasPrice": "0x17dd79e100",
          "maxFeePerGas": "0x2381b55500",
          "maxPriorityFeePerGas": "0x9502f900",
          "input": "0x1fad948c",
          "type": "0x2",
          "status": "0x1",
          "gasUsed": "0xbe974",
          "effectiveGasPrice": "0x17dd79e100",
          "logs": [
            {
              "address": "0x534b2f3a",
              "topics": ["0xddf252ad", "0x00000000"],
              "data": "0x00000003e8",
              "blockNumber": "0x11804a5",
              "transactionHash": "0x7a2ddf10",
              "logIndex": "0x9"
            }
          ],
          "contractAddress": null
        },
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": {
        "chainId": "eip155:10143",
        "signature": "0x7a2ddf10"
      }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)

    XCTAssertNotNil(response.data.evmTransaction)
    XCTAssertNil(response.data.evmUserOperation)
    XCTAssertNil(response.data.solanaTransaction)
    XCTAssertNil(response.data.bitcoinTransaction)
    XCTAssertNil(response.data.stellarTransaction)
    XCTAssertNil(response.data.tronTransaction)

    let tx = response.data.evmTransaction!
    XCTAssertEqual(tx.hash, "0x7a2ddf10")
    XCTAssertEqual(tx.from, "0x4337003f")
    XCTAssertEqual(tx.to, "0x5ff137d4")
    XCTAssertEqual(tx.value, "0x0")
    XCTAssertEqual(tx.nonce, "0x162e")
    XCTAssertEqual(tx.gas, "0xbe974")
    XCTAssertEqual(tx.type, "0x2")
    XCTAssertEqual(tx.status, "0x1")
    XCTAssertNil(tx.contractAddress)

    XCTAssertEqual(tx.logs?.count, 1)
    XCTAssertEqual(tx.logs?[0].address, "0x534b2f3a")
    XCTAssertEqual(tx.logs?[0].topics.count, 2)

    XCTAssertEqual(response.metadata.chainId, "eip155:10143")
    XCTAssertEqual(response.metadata.signature, "0x7a2ddf10")
  }

  func test_decode_evmTransaction_withNullableFieldsNull() throws {
    let json = """
    {
      "data": {
        "evmTransaction": {
          "hash": "0xabc",
          "from": "0x123",
          "to": null,
          "value": "0x0",
          "nonce": "0x1",
          "blockNumber": null,
          "blockHash": null,
          "transactionIndex": null,
          "gas": "0x5208",
          "gasPrice": null,
          "maxFeePerGas": null,
          "maxPriorityFeePerGas": null,
          "input": "0x",
          "type": "0x0",
          "status": null,
          "gasUsed": null,
          "effectiveGasPrice": null,
          "logs": null,
          "contractAddress": null
        },
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "eip155:1", "signature": "0xabc" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.evmTransaction!

    XCTAssertNil(tx.to)
    XCTAssertNil(tx.blockNumber)
    XCTAssertNil(tx.blockHash)
    XCTAssertNil(tx.transactionIndex)
    XCTAssertNil(tx.gasPrice)
    XCTAssertNil(tx.maxFeePerGas)
    XCTAssertNil(tx.maxPriorityFeePerGas)
    XCTAssertNil(tx.status)
    XCTAssertNil(tx.gasUsed)
    XCTAssertNil(tx.effectiveGasPrice)
    XCTAssertNil(tx.logs)
    XCTAssertNil(tx.contractAddress)
  }
}

// MARK: - EVM User Operation decoding tests

extension GetTransactionDetailsTests {
  func test_decode_evmUserOperation_fromFullJSON() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": {
          "sender": "0xe9791af5",
          "nonce": "0x1",
          "callData": "0x51945447",
          "callGasLimit": "0x2a2d8",
          "verificationGasLimit": "0x405bf",
          "preVerificationGas": "0x81bc7",
          "maxFeePerGas": "0x2548319940",
          "maxPriorityFeePerGas": "0x9c765240",
          "signature": "0x00000000cf3e",
          "entryPoint": "0x5FF137D4",
          "success": true,
          "actualGasCost": "0x10fadccba5a4700",
          "actualGasUsed": "0xb5ebc",
          "receipt": {
            "hash": "0x7a2ddf10",
            "from": "0x4337003f",
            "to": "0x5ff137d4",
            "value": "0x0",
            "nonce": "0x162e",
            "blockNumber": "0x11804a5",
            "blockHash": "0x1d918839",
            "transactionIndex": "0x4",
            "gas": "0xbe974",
            "gasPrice": "0x17dd79e100",
            "maxFeePerGas": null,
            "maxPriorityFeePerGas": null,
            "input": "0x1fad948c",
            "type": "0x2",
            "status": "0x1",
            "gasUsed": "0xbe974",
            "effectiveGasPrice": "0x17dd79e100",
            "logs": [],
            "contractAddress": null
          }
        },
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "eip155:10143", "signature": "0x87981bfa" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)

    XCTAssertNil(response.data.evmTransaction)
    XCTAssertNotNil(response.data.evmUserOperation)

    let op = response.data.evmUserOperation!
    XCTAssertEqual(op.sender, "0xe9791af5")
    XCTAssertEqual(op.nonce, "0x1")
    XCTAssertEqual(op.callData, "0x51945447")
    XCTAssertEqual(op.entryPoint, "0x5FF137D4")
    XCTAssertEqual(op.success, true)
    XCTAssertEqual(op.actualGasCost, "0x10fadccba5a4700")
    XCTAssertNotNil(op.receipt)
    XCTAssertEqual(op.receipt?.hash, "0x7a2ddf10")
  }

  func test_decode_evmUserOperation_withNullReceipt() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": {
          "sender": "0xabc",
          "nonce": "0x0",
          "callData": "0x",
          "callGasLimit": "0x0",
          "verificationGasLimit": "0x0",
          "preVerificationGas": "0x0",
          "maxFeePerGas": "0x0",
          "maxPriorityFeePerGas": "0x0",
          "signature": "0x",
          "entryPoint": "0x5FF137D4",
          "success": null,
          "actualGasCost": null,
          "actualGasUsed": null,
          "receipt": null
        },
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "eip155:1", "signature": "0x123" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let op = response.data.evmUserOperation!

    XCTAssertNil(op.success)
    XCTAssertNil(op.actualGasCost)
    XCTAssertNil(op.actualGasUsed)
    XCTAssertNil(op.receipt)
  }
}

// MARK: - Solana Transaction decoding tests

extension GetTransactionDetailsTests {
  func test_decode_solanaTransaction_fromFullJSON() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": {
          "blockTime": 1747834869,
          "error": null,
          "signature": "4U9JaGKb86",
          "status": "finalized",
          "transactionDetails": {
            "transaction": {
              "message": {
                "accountKeys": ["75ZfLXXs", "G7YWAJfN"],
                "header": {
                  "numReadonlySignedAccounts": 0,
                  "numReadonlyUnsignedAccounts": 2,
                  "numRequiredSignatures": 1
                },
                "instructions": [
                  {
                    "accounts": [0, 1],
                    "data": "3Bxs4Bc3",
                    "programIdIndex": 2,
                    "stackHeight": 1
                  }
                ],
                "recentBlockhash": "4KLaCt6P"
              },
              "signatures": ["4U9JaGKb86"]
            },
            "signatureDetails": {
              "blockTime": 1747834869,
              "confirmationStatus": "finalized",
              "error": null,
              "memo": null,
              "signature": "4U9JaGKb86",
              "slot": 382356122
            },
            "metadata": {
              "blockTime": 1747834869,
              "slot": 382356122,
              "error": null,
              "fee": 80000,
              "innerInstructions": [],
              "loadedAddresses": { "readonly": [], "writable": [] },
              "logMessages": ["Program invoke [1]", "Program success"],
              "postBalances": [19144038386, 1000000],
              "postTokenBalances": [],
              "preBalances": [19145118386, 0],
              "preTokenBalances": [],
              "rewards": [],
              "status": { "Ok": null },
              "version": "legacy"
            }
          }
        },
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", "signature": "4U9JaGKb86" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)

    XCTAssertNotNil(response.data.solanaTransaction)
    let tx = response.data.solanaTransaction!
    XCTAssertEqual(tx.blockTime, 1747834869)
    XCTAssertNil(tx.error)
    XCTAssertEqual(tx.signature, "4U9JaGKb86")
    XCTAssertEqual(tx.status, "finalized")

    let details = tx.transactionDetails!
    XCTAssertEqual(details.transaction?.signatures, ["4U9JaGKb86"])
    XCTAssertEqual(details.transaction?.message?.accountKeys, ["75ZfLXXs", "G7YWAJfN"])
    XCTAssertEqual(details.transaction?.message?.header?.numRequiredSignatures, 1)
    XCTAssertEqual(details.transaction?.message?.instructions?.count, 1)
    XCTAssertEqual(details.transaction?.message?.instructions?[0].programIdIndex, 2)
    XCTAssertEqual(details.signatureDetails?.confirmationStatus, "finalized")
    XCTAssertEqual(details.signatureDetails?.slot, 382356122)
    XCTAssertEqual(details.metadata?.fee, 80000)
    XCTAssertEqual(details.metadata?.logMessages?.count, 2)
    XCTAssertEqual(details.metadata?.version, "legacy")

    XCTAssertEqual(response.metadata.chainId, "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  }
}

// MARK: - Bitcoin Transaction decoding tests

extension GetTransactionDetailsTests {
  func test_decode_bitcoinTransaction_fromFullJSON() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": {
          "txid": "cb56ab9f",
          "version": 2,
          "size": 222,
          "weight": 561,
          "locktime": 0,
          "fee": 280,
          "status": {
            "confirmed": true,
            "blockHeight": 4814068,
            "blockHash": null,
            "blockTime": 1768583503
          },
          "vin": [
            {
              "txid": "1451fd4b",
              "vout": 1,
              "prevout": {
                "scriptpubkey": "001400",
                "scriptpubkey_address": "tb1qabc",
                "value": 18906
              },
              "scriptsig": "",
              "witness": ["304402"],
              "sequence": 4294967295
            }
          ],
          "vout": [
            {
              "scriptpubkey": "0014b425cc06",
              "scriptpubkey_address": "tb1qksjucp5al0l38",
              "value": 10000
            },
            {
              "scriptpubkey": "0014dd3c3679",
              "scriptpubkey_address": "tb1qm57rv7du65k9",
              "value": 8626
            }
          ]
        },
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "bip122:000000000933ea01ad0ee984209779ba-p2wpkh", "signature": "cb56ab9f" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)

    XCTAssertNotNil(response.data.bitcoinTransaction)
    let tx = response.data.bitcoinTransaction!
    XCTAssertEqual(tx.txid, "cb56ab9f")
    XCTAssertEqual(tx.version, 2)
    XCTAssertEqual(tx.size, 222)
    XCTAssertEqual(tx.weight, 561)
    XCTAssertEqual(tx.locktime, 0)
    XCTAssertEqual(tx.fee, 280)

    XCTAssertEqual(tx.status.confirmed, true)
    XCTAssertEqual(tx.status.blockHeight, 4814068)
    XCTAssertNil(tx.status.blockHash)
    XCTAssertEqual(tx.status.blockTime, 1768583503)

    XCTAssertEqual(tx.vin.count, 1)
    XCTAssertEqual(tx.vin[0].txid, "1451fd4b")
    XCTAssertEqual(tx.vin[0].vout, 1)
    XCTAssertEqual(tx.vin[0].prevout?.scriptpubkeyAddress, "tb1qabc")
    XCTAssertEqual(tx.vin[0].prevout?.value, 18906)
    XCTAssertEqual(tx.vin[0].witness, ["304402"])
    XCTAssertEqual(tx.vin[0].sequence, 4294967295)

    XCTAssertEqual(tx.vout.count, 2)
    XCTAssertEqual(tx.vout[0].scriptpubkeyAddress, "tb1qksjucp5al0l38")
    XCTAssertEqual(tx.vout[0].value, 10000)
    XCTAssertEqual(tx.vout[1].value, 8626)
  }

  func test_decode_bitcoinTransaction_snakeCaseMappingWorks() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": {
          "txid": "abc",
          "version": 1,
          "size": 100,
          "weight": 400,
          "locktime": 0,
          "fee": 100,
          "status": { "confirmed": false, "blockHeight": null, "blockHash": null, "blockTime": null },
          "vin": [{
            "txid": "def",
            "vout": 0,
            "prevout": { "scriptpubkey": "00", "scriptpubkey_address": "addr1", "value": 500 },
            "scriptsig": "",
            "witness": [],
            "sequence": 0
          }],
          "vout": [{ "scriptpubkey": "01", "scriptpubkey_address": "addr2", "value": 400 }]
        },
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "bip122:test", "signature": "abc" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.bitcoinTransaction!

    XCTAssertEqual(tx.vin[0].prevout?.scriptpubkeyAddress, "addr1")
    XCTAssertEqual(tx.vout[0].scriptpubkeyAddress, "addr2")
  }
}

// MARK: - Stellar Transaction decoding tests

extension GetTransactionDetailsTests {
  func test_decode_stellarTransaction_fromFullJSON() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": {
          "id": "c21b3ba7",
          "hash": "c21b3ba7",
          "ledger": 1586182,
          "createdAt": "2026-03-19T14:56:39Z",
          "sourceAccount": "GC7W7UECSSCQFFCM3RYSBO247KIAEQNFBKPUAFMB436X3LWWXR7PF2UM",
          "feeCharged": "100",
          "maxFee": "10000",
          "operationCount": 1,
          "successful": true,
          "memo": null,
          "memoType": "none",
          "operations": []
        },
        "tronTransaction": null
      },
      "metadata": { "chainId": "stellar:testnet", "signature": "c21b3ba7" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)

    XCTAssertNotNil(response.data.stellarTransaction)
    let tx = response.data.stellarTransaction!
    XCTAssertEqual(tx.id, "c21b3ba7")
    XCTAssertEqual(tx.hash, "c21b3ba7")
    XCTAssertEqual(tx.ledger, 1586182)
    XCTAssertEqual(tx.createdAt, "2026-03-19T14:56:39Z")
    XCTAssertEqual(tx.sourceAccount, "GC7W7UECSSCQFFCM3RYSBO247KIAEQNFBKPUAFMB436X3LWWXR7PF2UM")
    XCTAssertEqual(tx.feeCharged, "100")
    XCTAssertEqual(tx.maxFee, "10000")
    XCTAssertEqual(tx.operationCount, 1)
    XCTAssertEqual(tx.successful, true)
    XCTAssertNil(tx.memo)
    XCTAssertEqual(tx.memoType, "none")

    XCTAssertEqual(response.metadata.chainId, "stellar:testnet")
  }
}

// MARK: - Tron Transaction decoding tests

extension GetTransactionDetailsTests {
  func test_decode_tronTransaction_fromFullJSON() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": {
          "txID": "74ffe63b",
          "blockNumber": 55205096,
          "blockTimeStamp": 1741808940000,
          "contractResult": ["SUCCESS"],
          "receipt": {
            "result": "SUCCESS",
            "energyUsage": null,
            "energyUsageTotal": 29650,
            "netUsage": 344
          },
          "contractType": "TriggerSmartContract",
          "contractData": {
            "data": "a9059cbb",
            "owner_address": "414a83df",
            "contract_address": "41eca9bc"
          },
          "result": "SUCCESS"
        }
      },
      "metadata": { "chainId": "tron:nile", "signature": "74ffe63b" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)

    XCTAssertNotNil(response.data.tronTransaction)
    let tx = response.data.tronTransaction!
    XCTAssertEqual(tx.txID, "74ffe63b")
    XCTAssertEqual(tx.blockNumber, 55205096)
    XCTAssertEqual(tx.blockTimeStamp, 1741808940000)
    XCTAssertEqual(tx.contractResult, ["SUCCESS"])
    XCTAssertEqual(tx.receipt?.result, "SUCCESS")
    XCTAssertNil(tx.receipt?.energyUsage)
    XCTAssertEqual(tx.receipt?.energyUsageTotal, 29650)
    XCTAssertEqual(tx.receipt?.netUsage, 344)
    XCTAssertEqual(tx.contractType, "TriggerSmartContract")
    XCTAssertNotNil(tx.contractData)
    XCTAssertEqual(tx.result, "SUCCESS")

    XCTAssertEqual(response.metadata.chainId, "tron:nile")
  }

  func test_decode_tronTransaction_withAllNullableFieldsNull() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": {
          "txID": "abc123",
          "blockNumber": null,
          "blockTimeStamp": null,
          "contractResult": [],
          "receipt": null,
          "contractType": null,
          "contractData": null,
          "result": null
        }
      },
      "metadata": { "chainId": "tron:nile", "signature": "abc123" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.tronTransaction!

    XCTAssertEqual(tx.txID, "abc123")
    XCTAssertNil(tx.blockNumber)
    XCTAssertNil(tx.blockTimeStamp)
    XCTAssertNil(tx.receipt)
    XCTAssertNil(tx.contractType)
    XCTAssertNil(tx.contractData)
    XCTAssertNil(tx.result)
  }
}

// MARK: - Empty / all-null response decoding tests

extension GetTransactionDetailsTests {
  func test_decode_allNullChains_fromJSON() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "eip155:1", "signature": "0x000" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)

    XCTAssertNil(response.data.evmTransaction)
    XCTAssertNil(response.data.evmUserOperation)
    XCTAssertNil(response.data.solanaTransaction)
    XCTAssertNil(response.data.bitcoinTransaction)
    XCTAssertNil(response.data.stellarTransaction)
    XCTAssertNil(response.data.tronTransaction)
    XCTAssertEqual(response.metadata.chainId, "eip155:1")
    XCTAssertEqual(response.metadata.signature, "0x000")
  }
}

// MARK: - EVM Transaction additional edge-case tests

extension GetTransactionDetailsTests {
  func test_decode_evmTransaction_withContractAddress() throws {
    let json = """
    {
      "data": {
        "evmTransaction": {
          "hash": "0xdeploy",
          "from": "0xdeployer",
          "to": null,
          "value": "0x0",
          "nonce": "0x0",
          "blockNumber": "0x100",
          "blockHash": "0xblockhash",
          "transactionIndex": "0x0",
          "gas": "0x5208",
          "gasPrice": "0x3b9aca00",
          "maxFeePerGas": null,
          "maxPriorityFeePerGas": null,
          "input": "0x6080604052",
          "type": "0x0",
          "status": "0x1",
          "gasUsed": "0x4000",
          "effectiveGasPrice": "0x3b9aca00",
          "logs": [],
          "contractAddress": "0xnewcontract"
        },
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "eip155:1", "signature": "0xdeploy" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.evmTransaction!

    XCTAssertNil(tx.to)
    XCTAssertEqual(tx.contractAddress, "0xnewcontract")
    XCTAssertEqual(tx.input, "0x6080604052")
    XCTAssertEqual(tx.logs?.count, 0)
  }

  func test_decode_evmTransaction_withMultipleLogs() throws {
    let json = """
    {
      "data": {
        "evmTransaction": {
          "hash": "0xmulti",
          "from": "0xsender",
          "to": "0xcontract",
          "value": "0x0",
          "nonce": "0x5",
          "blockNumber": "0x200",
          "blockHash": "0xbh2",
          "transactionIndex": "0x1",
          "gas": "0x10000",
          "gasPrice": "0x3b9aca00",
          "maxFeePerGas": null,
          "maxPriorityFeePerGas": null,
          "input": "0xabcdef",
          "type": "0x0",
          "status": "0x1",
          "gasUsed": "0x8000",
          "effectiveGasPrice": "0x3b9aca00",
          "logs": [
            {
              "address": "0xtoken1",
              "topics": ["0xddf252ad"],
              "data": "0x01",
              "blockNumber": "0x200",
              "transactionHash": "0xmulti",
              "logIndex": "0x0"
            },
            {
              "address": "0xtoken2",
              "topics": ["0xddf252ad", "0x00000001", "0x00000002"],
              "data": "0x02",
              "blockNumber": "0x200",
              "transactionHash": "0xmulti",
              "logIndex": "0x1"
            },
            {
              "address": "0xtoken3",
              "topics": [],
              "data": "0x03",
              "blockNumber": "0x200",
              "transactionHash": "0xmulti",
              "logIndex": "0x2"
            }
          ],
          "contractAddress": null
        },
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "eip155:1", "signature": "0xmulti" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.evmTransaction!

    XCTAssertEqual(tx.logs?.count, 3)
    XCTAssertEqual(tx.logs?[0].address, "0xtoken1")
    XCTAssertEqual(tx.logs?[0].logIndex, "0x0")
    XCTAssertEqual(tx.logs?[1].topics.count, 3)
    XCTAssertEqual(tx.logs?[2].topics.count, 0)
  }
}

// MARK: - EVM User Operation additional tests

extension GetTransactionDetailsTests {
  func test_decode_evmUserOperation_allGasFieldsExercised() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": {
          "sender": "0xuser",
          "nonce": "0xa",
          "callData": "0xcalldata",
          "callGasLimit": "0x1234",
          "verificationGasLimit": "0x5678",
          "preVerificationGas": "0x9abc",
          "maxFeePerGas": "0xdef0",
          "maxPriorityFeePerGas": "0x1111",
          "signature": "0xsig",
          "entryPoint": "0xep",
          "success": false,
          "actualGasCost": "0x2222",
          "actualGasUsed": "0x3333",
          "receipt": {
            "hash": "0xreceipt",
            "from": "0xbundler",
            "to": "0xep",
            "value": "0x0",
            "nonce": "0x10",
            "blockNumber": "0x500",
            "blockHash": "0xbh5",
            "transactionIndex": "0x2",
            "gas": "0x50000",
            "gasPrice": "0xdef0",
            "maxFeePerGas": "0xdef0",
            "maxPriorityFeePerGas": "0x1111",
            "input": "0x1fad948c",
            "type": "0x2",
            "status": "0x1",
            "gasUsed": "0x40000",
            "effectiveGasPrice": "0xdef0",
            "logs": [],
            "contractAddress": null
          }
        },
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "eip155:10143", "signature": "0xsig" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let op = response.data.evmUserOperation!

    XCTAssertEqual(op.callGasLimit, "0x1234")
    XCTAssertEqual(op.verificationGasLimit, "0x5678")
    XCTAssertEqual(op.preVerificationGas, "0x9abc")
    XCTAssertEqual(op.maxFeePerGas, "0xdef0")
    XCTAssertEqual(op.maxPriorityFeePerGas, "0x1111")
    XCTAssertEqual(op.success, false)
    XCTAssertEqual(op.actualGasCost, "0x2222")
    XCTAssertEqual(op.actualGasUsed, "0x3333")

    let receipt = op.receipt!
    XCTAssertEqual(receipt.hash, "0xreceipt")
    XCTAssertEqual(receipt.from, "0xbundler")
    XCTAssertEqual(receipt.maxFeePerGas, "0xdef0")
    XCTAssertEqual(receipt.maxPriorityFeePerGas, "0x1111")
    XCTAssertEqual(receipt.type, "0x2")
    XCTAssertEqual(receipt.logs?.count, 0)
  }
}

// MARK: - Solana Transaction additional tests

extension GetTransactionDetailsTests {
  func test_decode_solanaTransaction_withNullTransactionDetails() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": {
          "blockTime": null,
          "error": "TransactionExpired",
          "signature": "expiredSig",
          "status": "expired",
          "transactionDetails": null
        },
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "solana:devnet", "signature": "expiredSig" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.solanaTransaction!

    XCTAssertNil(tx.blockTime)
    XCTAssertEqual(tx.error, "TransactionExpired")
    XCTAssertEqual(tx.status, "expired")
    XCTAssertNil(tx.transactionDetails)
  }

  func test_decode_solanaTransaction_loadedAddresses() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": {
          "blockTime": 1747834869,
          "error": null,
          "signature": "sigLA",
          "status": "finalized",
          "transactionDetails": {
            "transaction": null,
            "signatureDetails": null,
            "metadata": {
              "blockTime": 1747834869,
              "slot": 100,
              "error": null,
              "fee": 5000,
              "innerInstructions": [],
              "loadedAddresses": {
                "readonly": ["addr1", "addr2"],
                "writable": ["addr3"]
              },
              "logMessages": ["Program log: ok"],
              "postBalances": [1000],
              "postTokenBalances": [],
              "preBalances": [2000],
              "preTokenBalances": [],
              "rewards": [],
              "status": { "Ok": null },
              "version": "0"
            }
          }
        },
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "solana:devnet", "signature": "sigLA" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let meta = response.data.solanaTransaction!.transactionDetails!.metadata!

    XCTAssertEqual(meta.loadedAddresses?.readonly, ["addr1", "addr2"])
    XCTAssertEqual(meta.loadedAddresses?.writable, ["addr3"])
    XCTAssertEqual(meta.fee, 5000)
    XCTAssertEqual(meta.version, "0")
    XCTAssertNil(response.data.solanaTransaction!.transactionDetails!.transaction)
    XCTAssertNil(response.data.solanaTransaction!.transactionDetails!.signatureDetails)
  }

  func test_decode_solanaTransaction_multipleInstructions() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": {
          "blockTime": 1747834869,
          "error": null,
          "signature": "sigMulti",
          "status": "finalized",
          "transactionDetails": {
            "transaction": {
              "message": {
                "accountKeys": ["key1", "key2", "key3"],
                "header": {
                  "numReadonlySignedAccounts": 1,
                  "numReadonlyUnsignedAccounts": 1,
                  "numRequiredSignatures": 2
                },
                "instructions": [
                  { "accounts": [0, 1], "data": "3Bxs4a", "programIdIndex": 2, "stackHeight": 1 },
                  { "accounts": [1, 2], "data": "9Pxs4b", "programIdIndex": 2, "stackHeight": 2 }
                ],
                "recentBlockhash": "blockhash123"
              },
              "signatures": ["sig1", "sig2"]
            },
            "signatureDetails": {
              "blockTime": 1747834869,
              "confirmationStatus": "finalized",
              "error": null,
              "memo": "test memo",
              "signature": "sigMulti",
              "slot": 999999
            },
            "metadata": null
          }
        },
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "solana:devnet", "signature": "sigMulti" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let details = response.data.solanaTransaction!.transactionDetails!

    XCTAssertEqual(details.transaction?.message?.instructions?.count, 2)
    XCTAssertEqual(details.transaction?.message?.instructions?[0].stackHeight, 1)
    XCTAssertEqual(details.transaction?.message?.instructions?[1].stackHeight, 2)
    XCTAssertEqual(details.transaction?.message?.header?.numRequiredSignatures, 2)
    XCTAssertEqual(details.transaction?.signatures?.count, 2)
    XCTAssertEqual(details.signatureDetails?.memo, "test memo")
    XCTAssertEqual(details.signatureDetails?.slot, 999999)
    XCTAssertNil(details.metadata)
  }
}

// MARK: - Bitcoin Transaction additional tests

extension GetTransactionDetailsTests {
  func test_decode_bitcoinTransaction_unconfirmed() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": {
          "txid": "pending123",
          "version": 2,
          "size": 150,
          "weight": 400,
          "locktime": 0,
          "fee": 150,
          "status": {
            "confirmed": false,
            "blockHeight": null,
            "blockHash": null,
            "blockTime": null
          },
          "vin": [{
            "txid": "prevtx",
            "vout": 0,
            "prevout": null,
            "scriptsig": "",
            "witness": ["3044", "02ab"],
            "sequence": 4294967293
          }],
          "vout": [
            { "scriptpubkey": "0014aabb", "scriptpubkey_address": "tb1qaddr1", "value": 5000 }
          ]
        },
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "bip122:test", "signature": "pending123" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.bitcoinTransaction!

    XCTAssertEqual(tx.status.confirmed, false)
    XCTAssertNil(tx.status.blockHeight)
    XCTAssertNil(tx.status.blockHash)
    XCTAssertNil(tx.status.blockTime)
    XCTAssertNil(tx.vin[0].prevout)
    XCTAssertEqual(tx.vin[0].witness, ["3044", "02ab"])
    XCTAssertEqual(tx.vin[0].sequence, 4294967293)
    XCTAssertEqual(tx.vout.count, 1)
    XCTAssertEqual(tx.vout[0].scriptpubkeyAddress, "tb1qaddr1")
  }

  func test_decode_bitcoinTransaction_multipleVinVout() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": {
          "txid": "multio",
          "version": 1,
          "size": 500,
          "weight": 1200,
          "locktime": 100,
          "fee": 500,
          "status": { "confirmed": true, "blockHeight": 800000, "blockHash": "0000abc", "blockTime": 1700000000 },
          "vin": [
            { "txid": "in1", "vout": 0, "prevout": { "scriptpubkey": "00", "scriptpubkey_address": "a1", "value": 1000 }, "scriptsig": "sig1", "witness": [], "sequence": 0 },
            { "txid": "in2", "vout": 1, "prevout": { "scriptpubkey": "01", "scriptpubkey_address": "a2", "value": 2000 }, "scriptsig": "sig2", "witness": ["w1"], "sequence": 1 }
          ],
          "vout": [
            { "scriptpubkey": "10", "scriptpubkey_address": "b1", "value": 1500 },
            { "scriptpubkey": "11", "scriptpubkey_address": "b2", "value": 900 },
            { "scriptpubkey": "12", "scriptpubkey_address": "b3", "value": 100 }
          ]
        },
        "stellarTransaction": null,
        "tronTransaction": null
      },
      "metadata": { "chainId": "bip122:mainnet", "signature": "multio" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.bitcoinTransaction!

    XCTAssertEqual(tx.vin.count, 2)
    XCTAssertEqual(tx.vout.count, 3)
    XCTAssertEqual(tx.locktime, 100)
    XCTAssertEqual(tx.vin[0].scriptsig, "sig1")
    XCTAssertEqual(tx.vin[1].prevout?.value, 2000)
    XCTAssertEqual(tx.status.blockHash, "0000abc")
    XCTAssertEqual(tx.vout[0].value + tx.vout[1].value + tx.vout[2].value, 2500)
  }
}

// MARK: - Stellar Transaction additional tests

extension GetTransactionDetailsTests {
  func test_decode_stellarTransaction_withMemo() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": {
          "id": "stellarWithMemo",
          "hash": "hashMemo",
          "ledger": 2000000,
          "createdAt": "2026-03-20T10:00:00Z",
          "sourceAccount": "GABC",
          "feeCharged": "200",
          "maxFee": "50000",
          "operationCount": 2,
          "successful": true,
          "memo": "payment-ref-12345",
          "memoType": "text",
          "operations": [{"type": "payment"}, {"type": "create_account"}]
        },
        "tronTransaction": null
      },
      "metadata": { "chainId": "stellar:pubnet", "signature": "hashMemo" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.stellarTransaction!

    XCTAssertEqual(tx.memo, "payment-ref-12345")
    XCTAssertEqual(tx.memoType, "text")
    XCTAssertEqual(tx.operationCount, 2)
    XCTAssertEqual(tx.operations.count, 2)
    XCTAssertEqual(tx.ledger, 2000000)
    XCTAssertEqual(tx.maxFee, "50000")
    XCTAssertEqual(response.metadata.chainId, "stellar:pubnet")
  }

  func test_decode_stellarTransaction_failedTransaction() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": {
          "id": "failedStellar",
          "hash": "hashFail",
          "ledger": 1500000,
          "createdAt": "2026-03-19T08:00:00Z",
          "sourceAccount": "GDEF",
          "feeCharged": "100",
          "maxFee": "10000",
          "operationCount": 1,
          "successful": false,
          "memo": null,
          "memoType": "none",
          "operations": []
        },
        "tronTransaction": null
      },
      "metadata": { "chainId": "stellar:testnet", "signature": "hashFail" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.stellarTransaction!

    XCTAssertEqual(tx.successful, false)
    XCTAssertEqual(tx.id, "failedStellar")
    XCTAssertNil(tx.memo)
    XCTAssertEqual(tx.operations.count, 0)
  }
}

// MARK: - Tron Transaction additional tests

extension GetTransactionDetailsTests {
  func test_decode_tronTransaction_withEnergyUsage() throws {
    let json = """
    {
      "data": {
        "evmTransaction": null,
        "evmUserOperation": null,
        "solanaTransaction": null,
        "bitcoinTransaction": null,
        "stellarTransaction": null,
        "tronTransaction": {
          "txID": "tronEnergy",
          "blockNumber": 60000000,
          "blockTimeStamp": 1800000000000,
          "contractResult": ["SUCCESS"],
          "receipt": {
            "result": "SUCCESS",
            "energyUsage": 15000,
            "energyUsageTotal": 45000,
            "netUsage": 500
          },
          "contractType": "TransferContract",
          "contractData": { "amount": 1000000, "to_address": "TAddr1", "owner_address": "TAddr2" },
          "result": "SUCCESS"
        }
      },
      "metadata": { "chainId": "tron:mainnet", "signature": "tronEnergy" }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(GetTransactionDetailsResponse.self, from: json)
    let tx = response.data.tronTransaction!

    XCTAssertEqual(tx.receipt?.energyUsage, 15000)
    XCTAssertEqual(tx.receipt?.energyUsageTotal, 45000)
    XCTAssertEqual(tx.receipt?.netUsage, 500)
    XCTAssertEqual(tx.blockNumber, 60000000)
    XCTAssertEqual(tx.blockTimeStamp, 1800000000000)
    XCTAssertNotNil(tx.contractData)
  }
}

// MARK: - Roundtrip encode/decode tests

extension GetTransactionDetailsTests {
  func test_roundtrip_evmTransaction() throws {
    let original = GetTransactionDetailsResponse.stub(
      data: .stubEvmTransaction(),
      metadata: .stub(chainId: "eip155:10143", signature: "0x7a2ddf10")
    )
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(GetTransactionDetailsResponse.self, from: data)

    XCTAssertEqual(decoded.metadata.chainId, original.metadata.chainId)
    XCTAssertEqual(decoded.metadata.signature, original.metadata.signature)
    XCTAssertNotNil(decoded.data.evmTransaction)
    XCTAssertEqual(decoded.data.evmTransaction?.hash, original.data.evmTransaction?.hash)
  }

  func test_roundtrip_evmUserOperation() throws {
    let original = GetTransactionDetailsResponse.stub(
      data: .stubEvmUserOperation(),
      metadata: .stub(chainId: "eip155:10143", signature: "0x87981bfa")
    )
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(GetTransactionDetailsResponse.self, from: data)

    XCTAssertNotNil(decoded.data.evmUserOperation)
    XCTAssertEqual(decoded.data.evmUserOperation?.sender, original.data.evmUserOperation?.sender)
    XCTAssertEqual(decoded.data.evmUserOperation?.success, true)
    XCTAssertNotNil(decoded.data.evmUserOperation?.receipt)
  }

  func test_roundtrip_bitcoinTransaction() throws {
    let original = GetTransactionDetailsResponse.stub(
      data: .stubBitcoinTransaction(),
      metadata: .stub(chainId: "bip122:000000000933ea01ad0ee984209779ba-p2wpkh", signature: "cb56ab9f")
    )
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(GetTransactionDetailsResponse.self, from: data)

    XCTAssertNotNil(decoded.data.bitcoinTransaction)
    XCTAssertEqual(decoded.data.bitcoinTransaction?.txid, original.data.bitcoinTransaction?.txid)
    XCTAssertEqual(decoded.data.bitcoinTransaction?.fee, 280)
    XCTAssertEqual(decoded.data.bitcoinTransaction?.vin.count, 1)
  }

  func test_roundtrip_stellarTransaction() throws {
    let original = GetTransactionDetailsResponse.stub(
      data: .stubStellarTransaction(),
      metadata: .stub(chainId: "stellar:testnet", signature: "c21b3ba7")
    )
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(GetTransactionDetailsResponse.self, from: data)

    XCTAssertNotNil(decoded.data.stellarTransaction)
    XCTAssertEqual(decoded.data.stellarTransaction?.id, original.data.stellarTransaction?.id)
    XCTAssertEqual(decoded.data.stellarTransaction?.successful, true)
  }

  func test_roundtrip_solanaTransaction() throws {
    let original = GetTransactionDetailsResponse.stub(
      data: .stubSolanaTransaction(),
      metadata: .stub(chainId: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", signature: "4U9JaGKb86")
    )
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(GetTransactionDetailsResponse.self, from: data)

    XCTAssertNotNil(decoded.data.solanaTransaction)
    XCTAssertEqual(decoded.data.solanaTransaction?.signature, "4U9JaGKb86")
    XCTAssertEqual(decoded.data.solanaTransaction?.status, "finalized")
  }

  func test_roundtrip_tronTransaction() throws {
    let original = GetTransactionDetailsResponse.stub(
      data: .stubTronTransaction(),
      metadata: .stub(chainId: "tron:nile", signature: "74ffe63b")
    )
    let data = try encoder.encode(original)
    let decoded = try decoder.decode(GetTransactionDetailsResponse.self, from: data)

    XCTAssertNotNil(decoded.data.tronTransaction)
    XCTAssertEqual(decoded.data.tronTransaction?.txID, original.data.tronTransaction?.txID)
    XCTAssertEqual(decoded.data.tronTransaction?.contractResult, ["SUCCESS"])
  }
}

// MARK: - Mock return value tests

extension GetTransactionDetailsTests {
  func test_getTransactionDetails_decodesEvmTransactionFromMock() async throws {
    // given
    let portalRequestMock = PortalRequestsMock()
    let stubResponse = GetTransactionDetailsResponse.stub(data: .stubEvmTransaction())
    portalRequestMock.returnValueData = try encoder.encode(stubResponse)
    initPortalApiWith(requests: portalRequestMock)

    // when
    let response = try await api?.getTransactionDetails(chain: "monad-testnet", signature: "0xabc")

    // then
    XCTAssertNotNil(response?.data.evmTransaction)
    XCTAssertNil(response?.data.evmUserOperation)
    XCTAssertNil(response?.data.solanaTransaction)
    XCTAssertNil(response?.data.bitcoinTransaction)
    XCTAssertNil(response?.data.stellarTransaction)
    XCTAssertNil(response?.data.tronTransaction)
    XCTAssertEqual(response?.data.evmTransaction?.hash, "0x7a2ddf10")
  }

  func test_getTransactionDetails_decodesBitcoinTransactionFromMock() async throws {
    // given
    let portalRequestMock = PortalRequestsMock()
    let stubResponse = GetTransactionDetailsResponse.stub(
      data: .stubBitcoinTransaction(),
      metadata: .stub(chainId: "bip122:test", signature: "cb56ab9f")
    )
    portalRequestMock.returnValueData = try encoder.encode(stubResponse)
    initPortalApiWith(requests: portalRequestMock)

    // when
    let response = try await api?.getTransactionDetails(
      chain: "bip122:000000000933ea01ad0ee984209779ba-p2wpkh",
      signature: "cb56ab9f"
    )

    // then
    XCTAssertNotNil(response?.data.bitcoinTransaction)
    XCTAssertEqual(response?.data.bitcoinTransaction?.txid, "cb56ab9f")
    XCTAssertEqual(response?.data.bitcoinTransaction?.status.confirmed, true)
  }

  func test_getTransactionDetails_decodesTronTransactionFromMock() async throws {
    // given
    let portalRequestMock = PortalRequestsMock()
    let stubResponse = GetTransactionDetailsResponse.stub(
      data: .stubTronTransaction(),
      metadata: .stub(chainId: "tron:nile", signature: "74ffe63b")
    )
    portalRequestMock.returnValueData = try encoder.encode(stubResponse)
    initPortalApiWith(requests: portalRequestMock)

    // when
    let response = try await api?.getTransactionDetails(chain: "tron:nile", signature: "74ffe63b")

    // then
    XCTAssertNotNil(response?.data.tronTransaction)
    XCTAssertEqual(response?.data.tronTransaction?.txID, "74ffe63b")
    XCTAssertEqual(response?.data.tronTransaction?.receipt?.result, "SUCCESS")
  }

  func test_getTransactionDetails_decodesSolanaTransactionFromMock() async throws {
    // given
    let portalRequestMock = PortalRequestsMock()
    let stubResponse = GetTransactionDetailsResponse.stub(
      data: .stubSolanaTransaction(),
      metadata: .stub(chainId: "solana:devnet", signature: "4U9JaGKb86")
    )
    portalRequestMock.returnValueData = try encoder.encode(stubResponse)
    initPortalApiWith(requests: portalRequestMock)

    // when
    let response = try await api?.getTransactionDetails(chain: "solana-devnet", signature: "4U9JaGKb86")

    // then
    XCTAssertNotNil(response?.data.solanaTransaction)
    XCTAssertNil(response?.data.evmTransaction)
    XCTAssertEqual(response?.data.solanaTransaction?.signature, "4U9JaGKb86")
    XCTAssertEqual(response?.data.solanaTransaction?.status, "finalized")
    XCTAssertEqual(response?.metadata.chainId, "solana:devnet")
  }

  func test_getTransactionDetails_decodesStellarTransactionFromMock() async throws {
    // given
    let portalRequestMock = PortalRequestsMock()
    let stubResponse = GetTransactionDetailsResponse.stub(
      data: .stubStellarTransaction(),
      metadata: .stub(chainId: "stellar:testnet", signature: "c21b3ba7")
    )
    portalRequestMock.returnValueData = try encoder.encode(stubResponse)
    initPortalApiWith(requests: portalRequestMock)

    // when
    let response = try await api?.getTransactionDetails(chain: "stellar:testnet", signature: "c21b3ba7")

    // then
    XCTAssertNotNil(response?.data.stellarTransaction)
    XCTAssertNil(response?.data.evmTransaction)
    XCTAssertNil(response?.data.bitcoinTransaction)
    XCTAssertEqual(response?.data.stellarTransaction?.id, "c21b3ba7")
    XCTAssertEqual(response?.data.stellarTransaction?.successful, true)
    XCTAssertEqual(response?.data.stellarTransaction?.feeCharged, "100")
    XCTAssertEqual(response?.metadata.chainId, "stellar:testnet")
  }

  func test_getTransactionDetails_decodesEvmUserOperationFromMock() async throws {
    // given
    let portalRequestMock = PortalRequestsMock()
    let stubResponse = GetTransactionDetailsResponse.stub(
      data: .stubEvmUserOperation(),
      metadata: .stub(chainId: "eip155:10143", signature: "0x87981bfa")
    )
    portalRequestMock.returnValueData = try encoder.encode(stubResponse)
    initPortalApiWith(requests: portalRequestMock)

    // when
    let response = try await api?.getTransactionDetails(chain: "monad-testnet", signature: "0x87981bfa")

    // then
    XCTAssertNil(response?.data.evmTransaction)
    XCTAssertNotNil(response?.data.evmUserOperation)
    XCTAssertNil(response?.data.solanaTransaction)
    XCTAssertEqual(response?.data.evmUserOperation?.sender, "0xe9791af5")
    XCTAssertEqual(response?.data.evmUserOperation?.success, true)
    XCTAssertNotNil(response?.data.evmUserOperation?.receipt)
    XCTAssertEqual(response?.data.evmUserOperation?.receipt?.hash, "0x7a2ddf10")
  }

  func test_getTransactionDetails_decodesEmptyResponseFromMock() async throws {
    // given
    let portalRequestMock = PortalRequestsMock()
    let stubResponse = GetTransactionDetailsResponse.stub(
      data: .stubEmpty(),
      metadata: .stub(chainId: "eip155:1", signature: "0xnotfound")
    )
    portalRequestMock.returnValueData = try encoder.encode(stubResponse)
    initPortalApiWith(requests: portalRequestMock)

    // when
    let response = try await api?.getTransactionDetails(chain: "eip155:1", signature: "0xnotfound")

    // then
    XCTAssertNil(response?.data.evmTransaction)
    XCTAssertNil(response?.data.evmUserOperation)
    XCTAssertNil(response?.data.solanaTransaction)
    XCTAssertNil(response?.data.bitcoinTransaction)
    XCTAssertNil(response?.data.stellarTransaction)
    XCTAssertNil(response?.data.tronTransaction)
    XCTAssertEqual(response?.metadata.signature, "0xnotfound")
  }
}

// MARK: - Spy integration tests

extension GetTransactionDetailsTests {
  func test_getTransactionDetails_spy_tracksCallCountAndParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let response = GetTransactionDetailsResponse.stub(data: .stubEvmTransaction())
    portalRequestsSpy.returnData = try encoder.encode(response)
    initPortalApiWith(requests: portalRequestsSpy)

    // when
    _ = try await api?.getTransactionDetails(chain: "chain1", signature: "sig1")
    _ = try await api?.getTransactionDetails(chain: "chain2", signature: "sig2")

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 2)
  }

  func test_getTransactionDetails_spy_eachCallBuildsIndependentUrl() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let response = GetTransactionDetailsResponse.stub(data: .stubEvmTransaction())
    portalRequestsSpy.returnData = try encoder.encode(response)
    initPortalApiWith(requests: portalRequestsSpy)

    // when
    _ = try await api?.getTransactionDetails(chain: "stellar:testnet", signature: "abc")

    // then
    if #available(iOS 16.0, *) {
      let urlString = portalRequestsSpy.executeRequestParam?.url.absoluteString ?? ""
      XCTAssertTrue(urlString.contains("stellar"))
      XCTAssertTrue(urlString.contains("/transactions/abc"))
    }
  }
}

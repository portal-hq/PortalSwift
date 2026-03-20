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
}

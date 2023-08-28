//
//  Constants.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public let mockAddress = "0x73574d2355"
public let mockBackupShare = "test-backup-share"
public let mockBackupPath = "test-backup-path"
public let mockCloudBackupPath = "test-cloud-backup-path"
public let mockGDriveFileId = "test-gdrive-file-id"
public let mockGDriveFileContents = "test-gdrive-private-key"
public let mockGDriveFolderId = "test-gdrive-folder-id"
public let mockCiphertext = "someCipherText"
public let mockClientId = "test-client-id"
public let mockApiKey = "test-api-key"
public let mockHost = "example.com"
public let mockTransactionHash = "0x926c5168c5646425d5dcf8e3dac7359ddb77e9ff95884393a6a9a8e3de066fc1"
public let mockTransaction = [
  "from": mockAddress,
  "to": "0xd46e8dd67c5d32be8058bb8eb970870f07244567",
  "value": "0x9184e72a",
  "data": "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675",
]
public let mockSigningShare = "{\"share\":\"65983908943105091459096482121662146120067302711502943170570402855073666555372\",\"bks\":{\"server\":{\"X\":\"36011448137708654226005205841643896432296548978325312052356584465044929203878\",\"Rank\":0},\"client\":{\"X\":\"53593456824119187266546565253674465913247674736650756382197673408841670869238\",\"Rank\":0}},\"pubkey\":{\"X\":\"71617445552292375690583369317551660053528762065941114595936426662200594080126\",\"Y\":\"12411795443735958621377360929048234093682788158582067148731088420280101511203\"}}"
public let mockClientSignResult = "{\"data\":\"54cdc8c44437159f524268bdf257d88743eb550def55171f9418c5abd9a994467aa000b3213e6cc1ae950b31631450faffbac7319c7ec096898314d1f289646900\",\"error\":{\"code\":0,\"message\":\"\"}}"
public let mockClientSignResultWithError = "{\"data\":\"\",\"error\":{\"code\":108,\"message\":\"This error is thrown if there is an issue completing the signing process.\"}}"
public let mockSignature = "54cdc8c44437159f524268bdf257d88743eb550def55171f9418c5abd9a994467aa000b3213e6cc1ae950b31631450faffbac7319c7ec096898314d1f289646900"
public let mockDataResult = "{\"data\":{\"address\":\"\(mockAddress)\",\"dkgResult\":{\"share\":\"shareValue\",\"allY\":{\"client\":{\"X\":\"clientX\",\"Y\":\"clientY\"},\"server\":{\"X\":\"serverX\",\"Y\":\"serverY\"}},\"bks\":{\"client\":{\"X\":\"clientX\",\"Rank\":0},\"server\":{\"X\":\"serverX\",\"Rank\":0}},\"p\":\"pValue\",\"partialPubkey\":{\"client\":{\"X\":\"clientX\",\"Y\":\"clientY\"},\"server\":{\"X\":\"serverX\",\"Y\":\"serverY\"}},\"pederson\":{\"client\":{\"n\":\"nValue\",\"s\":\"sValue\",\"t\":\"tValue\"},\"server\":{\"n\":\"nValue\",\"s\":\"sValue\",\"t\":\"tValue\"}},\"q\":\"qValue\",\"ssid\":\"ssidValue\",\"clientId\":\"clientIdValue\",\"pubkey\":{\"X\":\"pubkeyX\",\"Y\":\"pubkeyY\"}}},\"error\":{\"code\":0,\"message\":\"\"}}"
public let mockDecryptResult = "{\"data\":{\"plaintext\":\"signingShareObject\"},\"error\":{\"code\":0,\"message\":\"\"}}"

public let mockEncryptResult = "{\"data\":{\"key\":\"someKey\",\"cipherText\":\"\(mockCiphertext)\"},\"error\":{\"code\":0,\"message\":\"\"}}"

public let mockClientResult = "{\"data\":{\"id\":\"\(mockClientId)\",\"address\":\"\(mockAddress)\",\"clientApiKey\":\"\(mockApiKey)\",\"custodian\":{\"id\":\"someCustodianId\",\"name\":\"someCustodianName\"}},\"error\":{\"code\":0,\"message\":\"\"}}"

public let backupProgressCallbacks: Set<MpcStatuses> = [.readingShare, .generatingShare, .parsingShare, .encryptingShare, .storingShare, .done]

public let generateProgressCallbacks: Set<MpcStatuses> = [.generatingShare, .parsingShare, .storingShare, .done]

public let recoverProgressCallbacks: [MpcStatuses] = [.readingShare, .decryptingShare, .parsingShare, .recoveringSigningShare, .generatingShare, .parsingShare, .storingShare, .recoveringBackupShare, .generatingShare, .parsingShare, .encryptingShare, .storingShare, .done]

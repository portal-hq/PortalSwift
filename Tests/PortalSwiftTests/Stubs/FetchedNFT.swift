//
//  FetchedNFT.swift
//
//
//  Created by Ahmed Ragab on 04/09/2024.
//

import Foundation
@testable import PortalSwift

extension FetchedNFT {
  static func stub(
    contract: FetchedNFTContract = .stub(),
    id: FetchedNFTTokenId = .stub(),
    balance: String = "1",
    title: String = "Sample NFT",
    description: String = "This is a sample NFT",
    tokenUri: FetchedNFTTokenUri = .stub(),
    media: [FetchedNFTMedia] = [.stub()],
    metadata: FetchedNFTMetadata = .stub(),
    timeLastUpdated: String = "2024-08-24T12:00:00Z",
    contractMetadata: FetchedNFTContractMetadata = .stub()
  ) -> FetchedNFT {
    return FetchedNFT(
      contract: contract,
      id: id,
      balance: balance,
      title: title,
      description: description,
      tokenUri: tokenUri,
      media: media,
      metadata: metadata,
      timeLastUpdated: timeLastUpdated,
      contractMetadata: contractMetadata
    )
  }
}

extension FetchedNFTContract {
  static func stub(
    address: String = "0x123456789abcdef"
  ) -> FetchedNFTContract {
    return FetchedNFTContract(address: address)
  }
}

extension FetchedNFTTokenId {
  static func stub(
    tokenId: String = "1",
    tokenMetadata: FetchedNFTTokenMetadata = .stub()
  ) -> FetchedNFTTokenId {
    return FetchedNFTTokenId(
      tokenId: tokenId,
      tokenMetadata: tokenMetadata
    )
  }
}

extension FetchedNFTTokenUri {
  static func stub(
    gateway: String = "https://gateway.example.com/nft/1",
    raw: String = "ipfs://example"
  ) -> FetchedNFTTokenUri {
    return FetchedNFTTokenUri(
      gateway: gateway,
      raw: raw
    )
  }
}

extension FetchedNFTMedia {
  static func stub(
    gateway: String = "https://gateway.example.com/media/1",
    thumbnail: String = "https://gateway.example.com/media/1/thumbnail",
    raw: String = "ipfs://media",
    format: String = "image/png",
    bytes: Int = 123_456
  ) -> FetchedNFTMedia {
    return FetchedNFTMedia(
      gateway: gateway,
      thumbnail: thumbnail,
      raw: raw,
      format: format,
      bytes: bytes
    )
  }
}

extension FetchedNFTMetadata {
  static func stub(
    name: String = "Sample NFT",
    description: String = "This is a sample NFT description.",
    image: String = "https://gateway.example.com/media/1.png",
    external_url: String? = "https://example.com/nft/1"
  ) -> FetchedNFTMetadata {
    return FetchedNFTMetadata(
      name: name,
      description: description,
      image: image,
      external_url: external_url
    )
  }
}

extension FetchedNFTContractMetadata {
  static func stub(
    name: String = "Sample Contract",
    symbol: String = "SC",
    tokenType: String = "ERC721",
    contractDeployer: String = "0xabcdef123456789",
    deployedBlockNumber: Int = 1_234_567,
    openSea: FetchedNFTContractOpenSeaMetadata? = nil
  ) -> FetchedNFTContractMetadata {
    return FetchedNFTContractMetadata(
      name: name,
      symbol: symbol,
      tokenType: tokenType,
      contractDeployer: contractDeployer,
      deployedBlockNumber: deployedBlockNumber,
      openSea: openSea
    )
  }
}

extension FetchedNFTTokenMetadata {
  static func stub(
    tokenType: String = "ERC721"
  ) -> FetchedNFTTokenMetadata {
    return FetchedNFTTokenMetadata(
      tokenType: tokenType
    )
  }
}

extension FetchedNFTContractOpenSeaMetadata {
  static func stub(
    collectionName: String = "Sample Collection",
    safelistRequestStatus: String = "verified",
    imageUrl: String? = "https://example.com/image.png",
    description: String = "This is a sample collection on OpenSea.",
    externalUrl: String = "https://opensea.io/collection/sample-collection",
    lastIngestedAt: String = "2024-08-24T12:00:00Z",
    floorPrice: Float? = 0.1,
    twitterUsername: String? = "SampleNFT",
    discordUrl: String? = "https://discord.gg/sample"
  ) -> FetchedNFTContractOpenSeaMetadata {
    return FetchedNFTContractOpenSeaMetadata(
      collectionName: collectionName,
      safelistRequestStatus: safelistRequestStatus,
      imageUrl: imageUrl,
      description: description,
      externalUrl: externalUrl,
      lastIngestedAt: lastIngestedAt,
      floorPrice: floorPrice,
      twitterUsername: twitterUsername,
      discordUrl: discordUrl
    )
  }
}

//
//  NftAsset.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 17/03/2025.
//

import Foundation
@testable import PortalSwift

// MARK: - Stub Methods

extension NftAsset {
  static func stub(
    nftID: String? = "nft_1",
    name: String? = "Example NFT",
    description: String? = "This is an example NFT",
    imageURL: String? = "https://example.com/image.jpg",
    chainID: String? = "1",
    contractAddress: String? = "0xContractAddress",
    tokenID: String? = "1",
    collection: Collection? = nil,
    lastSale: LastSale? = .stub(),
    rarity: Rarity? = .stub(),
    floorPrice: NftAssetFloorPrice? = .stub(),
    detailedInfo: DetailedInfo? = .stub()
  ) -> Self {
    return NftAsset(
      nftID: nftID,
      name: name,
      description: description,
      imageURL: imageURL,
      chainID: chainID,
      contractAddress: contractAddress,
      tokenID: tokenID,
      collection: collection,
      lastSale: lastSale,
      rarity: rarity,
      floorPrice: floorPrice,
      detailedInfo: detailedInfo
    )
  }
}

extension LastSale {
  static func stub(
    price: Double? = 100.0,
    currency: String? = "ETH",
    date: String? = "2023-10-01"
  ) -> Self {
    return LastSale(
      price: price,
      currency: currency,
      date: date
    )
  }
}

extension Rarity {
  static func stub(
    rank: Int? = 1,
    score: Double? = 99.9
  ) -> Self {
    return Rarity(
      rank: rank,
      score: score
    )
  }
}

extension NftAssetFloorPrice {
  static func stub(
    price: Double? = 50.0,
    currency: String? = "ETH"
  ) -> Self {
    return NftAssetFloorPrice(
      price: price,
      currency: currency
    )
  }
}

extension DetailedInfo {
  static func stub(
    ownerCount: Int? = 100,
    tokenCount: Int? = 1000,
    createdDate: String? = "2023-01-01",
    attributes: [Attribute]? = [],
    owners: [Owner]? = [.stub()],
    extendedCollectionInfo: ExtendedCollectionInfo? = .stub(),
    extendedSaleInfo: ExtendedSaleInfo? = .stub(),
    marketplaceInfo: [MarketplaceInfo]? = [.stub()],
    mediaInfo: MediaInfo? = .stub()
  ) -> Self {
    return DetailedInfo(
      ownerCount: ownerCount,
      tokenCount: tokenCount,
      createdDate: createdDate,
      attributes: attributes,
      owners: owners,
      extendedCollectionInfo: extendedCollectionInfo,
      extendedSaleInfo: extendedSaleInfo,
      marketplaceInfo: marketplaceInfo,
      mediaInfo: mediaInfo
    )
  }
}

extension Owner {
  static func stub(
    ownerAddress: String? = "0xOwnerAddress",
    quantity: Int? = 1,
    firstAcquiredDate: String? = "2023-01-01",
    lastAcquiredDate: String? = "2023-10-01"
  ) -> Self {
    return Owner(
      ownerAddress: ownerAddress,
      quantity: quantity,
      firstAcquiredDate: firstAcquiredDate,
      lastAcquiredDate: lastAcquiredDate
    )
  }
}

extension ExtendedCollectionInfo {
  static func stub(
    bannerImageURL: String? = "https://example.com/banner.jpg",
    externalURL: String? = "https://example.com",
    twitterUsername: String? = "example_twitter",
    discordURL: String? = "https://discord.gg/example",
    instagramUsername: String? = "example_instagram",
    mediumUsername: String? = "example_medium",
    telegramURL: String? = "https://t.me/example",
    distinctOwnerCount: Int? = 1000,
    distinctNftCount: Int? = 5000,
    totalQuantity: Int? = 10000
  ) -> Self {
    return ExtendedCollectionInfo(
      bannerImageURL: bannerImageURL,
      externalURL: externalURL,
      twitterUsername: twitterUsername,
      discordURL: discordURL,
      instagramUsername: instagramUsername,
      mediumUsername: mediumUsername,
      telegramURL: telegramURL,
      distinctOwnerCount: distinctOwnerCount,
      distinctNftCount: distinctNftCount,
      totalQuantity: totalQuantity
    )
  }
}

extension ExtendedSaleInfo {
  static func stub(
    fromAddress: String? = "0xFromAddress",
    toAddress: String? = "0xToAddress",
    priceUsdCents: Int? = 10000,
    transaction: String? = "0xTransactionHash",
    marketplaceID: String? = "marketplace_1",
    marketplaceName: String? = "Example Marketplace"
  ) -> Self {
    return ExtendedSaleInfo(
      fromAddress: fromAddress,
      toAddress: toAddress,
      priceUsdCents: priceUsdCents,
      transaction: transaction,
      marketplaceID: marketplaceID,
      marketplaceName: marketplaceName
    )
  }
}

extension MarketplaceInfo {
  static func stub(
    marketplaceID: String? = "marketplace_1",
    marketplaceName: String? = "Example Marketplace",
    marketplaceCollectionID: String? = "collection_1",
    nftURL: String? = "https://example.com/nft/1",
    collectionURL: String? = "https://example.com/collection/1",
    verified: Bool? = true,
    floorPrice: MarketplaceInfoFloorPrice? = .stub()
  ) -> Self {
    return MarketplaceInfo(
      marketplaceID: marketplaceID,
      marketplaceName: marketplaceName,
      marketplaceCollectionID: marketplaceCollectionID,
      nftURL: nftURL,
      collectionURL: collectionURL,
      verified: verified,
      floorPrice: floorPrice
    )
  }
}

extension MarketplaceInfoFloorPrice {
  static func stub(
    value: Double? = 50.0,
    paymentToken: PaymentToken? = .stub(),
    valueUsdCents: Int? = 5000
  ) -> Self {
    return MarketplaceInfoFloorPrice(
      value: value,
      paymentToken: paymentToken,
      valueUsdCents: valueUsdCents
    )
  }
}

extension PaymentToken {
  static func stub(
    paymentTokenID: String? = "payment_token_1",
    name: String? = "Ethereum",
    symbol: String? = "ETH",
    address: String? = "0xPaymentTokenAddress",
    decimals: Int? = 18
  ) -> Self {
    return PaymentToken(
      paymentTokenID: paymentTokenID,
      name: name,
      symbol: symbol,
      address: address,
      decimals: decimals
    )
  }
}

extension MediaInfo {
  static func stub(
    previews: Previews? = .stub(),
    animationURL: String? = "https://example.com/animation.mp4",
    backgroundColor: String? = "#FFFFFF"
  ) -> Self {
    return MediaInfo(
      previews: previews,
      animationURL: animationURL,
      backgroundColor: backgroundColor
    )
  }
}

extension Previews {
  static func stub(
    imageSmallURL: String? = "https://example.com/small.jpg",
    imageMediumURL: String? = "https://example.com/medium.jpg",
    imageLargeURL: String? = "https://example.com/large.jpg",
    imageOpengraphURL: String? = "https://example.com/opengraph.jpg",
    blurhash: String? = "U5F?5w00D%x^~q%Lt7Rj00xu?bM{",
    predominantColor: String? = "#000000"
  ) -> Self {
    return Previews(
      imageSmallURL: imageSmallURL,
      imageMediumURL: imageMediumURL,
      imageLargeURL: imageLargeURL,
      imageOpengraphURL: imageOpengraphURL,
      blurhash: blurhash,
      predominantColor: predominantColor
    )
  }
}

extension Attribute {
  static func stub(
    traitType: String? = "Trait Type",
    value: String? = "Trait Value"
  ) -> Self {
    return Attribute(
      traitType: traitType,
      value: value
    )
  }
}

extension Collection {
  static func stub(
    name: String? = "Example Collection",
    description: String? = "This is an example collection",
    imageURL: String? = "https://example.com/collection.jpg"
  ) -> Self {
    return Collection(
      name: name,
      description: description,
      imageURL: imageURL
    )
  }
}

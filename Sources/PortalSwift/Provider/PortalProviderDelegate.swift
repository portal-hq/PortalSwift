public protocol PortalProviderDelegate {
  func portalProvider(didRequestSigningApprovalForRequest: PortalProviderRequestWithId) -> Bool
}

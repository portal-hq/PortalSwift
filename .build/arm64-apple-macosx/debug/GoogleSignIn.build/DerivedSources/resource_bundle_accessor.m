#import <Foundation/Foundation.h>

NSBundle* GoogleSignIn_SWIFTPM_MODULE_BUNDLE() {
    NSURL *bundleURL = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"GoogleSignIn_GoogleSignIn.bundle"];

    NSBundle *preferredBundle = [NSBundle bundleWithURL:bundleURL];
    if (preferredBundle == nil) {
      return [NSBundle bundleWithPath:@"/Users/blakewilliams/development/portal/PortalSwift/.build/arm64-apple-macosx/debug/GoogleSignIn_GoogleSignIn.bundle"];
    }

    return preferredBundle;
}
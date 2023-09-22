echo "Delete existing package directory..."
rm -rf portal-swift-spm

echo "Create package directory..."
mkdir portal-swift-spm

echo "Creating package subdirectories..."
mkdir portal-swift-spm/Sources
mkdir portal-swift-spm/Sources/PortalSwift

echo "Copy files to package directory..."
cp -R PortalSwift/Classes portal-swift-spm/Sources/PortalSwift
cp -R PortalSwift/Frameworks portal-swift-spm/Sources/PortalSwift

echo "Copying package file..."
cp Package.swift portal-swift-spm/

echo "Moving to package directory..."
cd portal-swift-spm

echo "Building package..."
# swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios14.0-simulator"
# xcodebuild -scheme PortalSwift -sdk iphoneos -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.4'
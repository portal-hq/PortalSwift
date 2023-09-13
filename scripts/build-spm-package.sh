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
cp PortalSwift/Package.swift portal-swift-spm/

echo "Moving to package directory..."
cd portal-swift-spm

echo "Building package..."
xcodebuild -scheme PortalSwift
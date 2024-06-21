#!/bin/bash

# Get the version from environment variable
VERSION=$1

# Update Version.swift
VERSION_FILE="Sources/PortalSwift/utils/Version.swift"
echo "// Version.swift
import Foundation

let SDK_VERSION = \"$VERSION\"" > $VERSION_FILE

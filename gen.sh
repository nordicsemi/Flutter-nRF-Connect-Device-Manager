#!/bin/sh

install_or_upgrade() {
    if brew list --versions "$1" >/dev/null 2>&1; then
        brew upgrade "$1"
    else
        brew install "$1"
    fi
}

install_or_upgrade protobuf
install_or_upgrade swift-protobuf

dart pub install
export PATH="$PATH":"$HOME/.pub-cache/bin"
dart pub global activate protoc_plugin

protoc --dart_out=./ --experimental_allow_proto3_optional lib/proto/flutter_mcu.proto --plugin ~/.pub-cache/bin/protoc-gen-dart
protoc -I lib/proto --swift_out=darwin/mcumgr_flutter/Sources/mcumgr_flutter/lib/proto/ flutter_mcu.proto --experimental_allow_proto3_optional

# Android Kotlin proto code is generated at build time by the Wire Gradle
# plugin (see the `wire {}` block in android/build.gradle), not by protoc.

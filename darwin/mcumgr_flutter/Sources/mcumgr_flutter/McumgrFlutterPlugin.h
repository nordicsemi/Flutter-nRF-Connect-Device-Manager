#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif

#if __has_include(<mcumgr_flutter/mcumgr_flutter-Swift.h>)
#import <mcumgr_flutter/mcumgr_flutter-Swift.h>
#else
#import "mcumgr_flutter-Swift.h"
#endif

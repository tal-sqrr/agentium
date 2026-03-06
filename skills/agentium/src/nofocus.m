#import <AppKit/AppKit.h>
#import <objc/runtime.h>

// Injected into Chrome for Testing via DYLD_INSERT_LIBRARIES.
// Suppresses focus stealing by no-opping activation methods.

static void noop_activate(__unused id self, __unused SEL _cmd, __unused BOOL flag) {}
static void noop_activate0(__unused id self, __unused SEL _cmd) {}

__attribute__((constructor))
static void install_nofocus(void) {
    Method m = class_getInstanceMethod([NSApplication class],
                                       @selector(activateIgnoringOtherApps:));
    if (m) method_setImplementation(m, (IMP)noop_activate);

    Method m2 = class_getInstanceMethod([NSApplication class],
                                        @selector(activate));
    if (m2) method_setImplementation(m2, (IMP)noop_activate0);
}

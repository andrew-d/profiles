#import <Foundation/Foundation.h>

#include "loaded_libraries.hpp"
#include "memory_regions.hpp"

#include <inttypes.h>
#include <boost/algorithm/string/predicate.hpp>

#include "util.h"
#include "interfaces.h"


// This struct emulates the CFString's in-memory layout.
typedef struct {
  void*    ptr1;
  uint64_t val1;
  char*    string;
  uint64_t len;
} fakeCFString;

// Get the base address of the ConfigurationProfiles framework
uintptr_t getFrameworkBase() {
  static const char* kFrameworkPath = "/System/Library/PrivateFrameworks/ConfigurationProfiles.framework";

  auto allLibs = LibraryInfo::getAll();
  for (const auto& lib : allLibs) {
    auto path = lib.realImageFilePath();
    if (boost::algorithm::starts_with(path, kFrameworkPath)) {
      return lib.imageLoadAddress();
    }
  }

  return 0;
}

// Get the OS-specific offset into the ConfigurationProfiles framework.
ptrdiff_t getInstructionOffset() {
  // TODO: better way of determining the major/minor/patch version
  int major = 10, minor = 11, patch = 1;

  if (major != 10) {
    return 0;
  }

  switch (minor) {
  case 11:
    // Tested on 10.11.1
    return 0x1f058;

  case 10:
    // Tested on 10.10.5
    return 0x1d09b;

  case 9:
    // Tested on 10.9.5
    return 0x1ac3c;

  default:
    return 0;
  }
}

// Patch the framework, returning whether or not we could do so.
bool patchFramework() {
  static const char* kPatchTarget = "/usr/bin/profiles";

  uintptr_t libStart = getFrameworkBase();
  if (libStart == 0) {
    NSLog(@"Framework not found");
    return false;
  }

  ptrdiff_t offset = getInstructionOffset();
  if (offset == 0) {
    NSLog(@"Unknown OS - can not determine offset");
    return false;
  }

  // This is a giant hack.  This instruction is in the `GetCallerType` block, and should be:
  //    leaq   -0xXXXXXXXX(%rip), %rax
  // Where the 'X's are the RIP-relative address of the CFString.  As bytes:
  //    0x48 0x8d 0x05 0xXX 0xXX 0xXX 0xXX
  uint8_t* instructionOffset = (uint8_t*)(libStart + offset);
  if ((*(instructionOffset + 0) != 0x48) ||
      (*(instructionOffset + 1) != 0x8d) ||
      (*(instructionOffset + 2) != 0x05)) {
    NSLog(@"Unknown instruction - not continuing");
    return false;
  }

  int32_t cfOffset = *(int32_t*)(instructionOffset + 3);

  // Note: we get the address of the CFString by emulating the RIP-relative addressing:
  //        instruction address + instruction length + offset from instruction
  //                 |                   |                         |
  //                 |                   |                         +----+
  //                 |                   +----------------------+       |
  //                 +-----------------------------+            |       |
  //                                               v            v       v
  fakeCFString *stringPtr = (fakeCFString*)(instructionOffset + 7 + cfOffset);

  // Validate that this string matches what we are expecting to overwrite:
  if (stringPtr->val1 != 0x7c8 ||
      stringPtr->len != strlen(kPatchTarget) ||
      0 != strcmp(stringPtr->string, kPatchTarget)) {
    NSLog(@"Invalid stringPtr - not continuing");
    return false;
  }

  // NOTE: we never free this path, since it lives "forever"
  char* ourPath = getPathForPid(getpid());

  // Everything looks good!
  stringPtr->string = ourPath;
  stringPtr->len = strlen(ourPath);
  return true;
}

// Actually call ConfigurationProfiles.framework to get/print all configuration profiles.
void getAllProfiles(CPProfileManager *mgr) {
  NSSet *profs = [mgr allProfiles:nil];

  NSLog(@"There are %lu profiles in the set", (unsigned long)[profs count]);

  for (CPProfile* prof in profs) {
    NSLog(@"Profile: %@ - %@",
      [prof profileIdentifier],
      [prof name]);
  }
}

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  if (patchFramework()) {
    CPProfileManager *mgr = [CPProfileManager sharedProfileManager];
    if (mgr) {
      getAllProfiles(mgr);
    } else {
      NSLog(@"Error creating CPProfileManager");
    }
  } else {
    NSLog(@"Could not patch our path");
  }

  [pool drain];
  return 0;
}

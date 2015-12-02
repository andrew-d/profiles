#import <Foundation/Foundation.h>

#include "loaded_libraries.hpp"
#include "memory_regions.hpp"

#include <inttypes.h>
#include <boost/algorithm/string/predicate.hpp>

#include "interfaces.h"


char* getPathForPid(pid_t pid) {
  CFNumberRef value = NULL;
  CFDictionaryRef attributes = NULL;
  SecCodeRef code = NULL;
  CFURLRef path = NULL;
  CFStringRef posixPath = NULL;
  OSStatus status;
  char* ret = NULL;

  value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pid);
  if (value == NULL)
    goto done;

  attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void **)&kSecGuestAttributePid, (const void **)&value, 1, NULL, NULL);
  if (attributes == NULL)
    goto done;

  status = SecCodeCopyGuestWithAttributes(NULL, attributes, kSecCSDefaultFlags, &code);
  if (status)
    goto done;

  status = SecCodeCopyPath(code, kSecCSDefaultFlags, &path);
  if (status)
    goto done;

  posixPath = CFURLCopyFileSystemPath(path, kCFURLPOSIXPathStyle);
  if (path == NULL)
    goto done;

  ret = strdup(CFStringGetCStringPtr(posixPath, kCFStringEncodingUTF8));

done:
  if (posixPath)  CFRelease(posixPath);
  if (path)       CFRelease(path);
  if (code)       CFRelease(code);
  if (attributes) CFRelease(attributes);
  if (value)      CFRelease(value);

  return ret;
}


void getAllProfiles(CPProfileManager *mgr) {
  NSSet *profs = [mgr allProfiles:nil];

  NSLog(@"There are %lu profiles in the set", (unsigned long)[profs count]);

  for (CPProfile* prof in profs) {
    NSLog(@"Profile: %@ - %@",
      [prof profileIdentifier],
      [prof name]
      );
  }
}

bool patchInRegion(uintptr_t start, uintptr_t end) {
  static const char* kPatchTarget = "/System/Library/PrivateFrameworks/IASUtilities.framework/Versions/A/XPCServices/com.apple.IASUtilities.IASCloudConfigHelper.xpc";

  // Get our path
  const char* ourPath = getPathForPid(getpid());
  NSLog(@"Our path = %s", ourPath);

  if (strlen(ourPath) > strlen(kPatchTarget)) {
    NSLog(@"Do not have enough space for our binary path!");
    free((void*)ourPath);
    return false;
  }

  bool patched = false;
  for (uintptr_t addr = start; addr < end; addr++) {
    if (0 == strcmp((char*)addr, kPatchTarget)) {
      NSLog(@"Found target string at: %p", (void*)addr);

      // Protect
      auto ret = vm_protect(
        mach_task_self(),
        (vm_address_t)addr,
        (vm_size_t)strlen(ourPath),
        false,
        VM_PROT_ALL
      );
      if (ret) {
        NSLog(@"Failed vm_protect @ %p: %d", (void*)addr, ret);
        continue;
      }

      // Copy
      strcpy((char*)addr, ourPath);
      NSLog(@"Successfully patched path at %p (path = '%s')", (void*)addr, (char*)addr);
      patched = true;
      break;
    }
  }

  free((void*)ourPath);
  return patched;
}

bool patchFramework() {
  static const char* kFrameworkPath = "/System/Library/PrivateFrameworks/ConfigurationProfiles.framework";

  // Find the 'ConfigurationProfile.framework' library
  auto allLibs = LibraryInfo::getAll();
  uintptr_t libStart = 0;

  for (const auto& lib : allLibs) {
    NSLog(@"[%16lx] %s", lib.imageLoadAddress(), lib.realImageFilePath().c_str());

    auto path = lib.realImageFilePath();
    if (boost::algorithm::starts_with(path, kFrameworkPath)) {
      libStart = lib.imageLoadAddress();
      break;
    }
  }

  if (libStart == 0) {
    NSLog(@"Framework not found");
    return false;
  }

  NSLog(@"Framework starts at: %p", (void*)libStart);

  // Get all memory regions.  Note that we don't get subregions - we just want
  // to find the main region, and then we can search forward from the image
  // header.
  auto regions = RegionInfo::getAll(mach_task_self(), false);

  // For each region, if it contains the image's start address, then we print it.
  for (const auto& info : regions) {
    NSLog(@"%p - %p [%s] (%d)",
      (void*)info.start(),
      (void*)info.end(),
      info.displaySize().c_str(),
      info.depth()
      );

    if (info.start() <= libStart && info.end() >= libStart) {
      NSLog(@"Found region that contains image: %p - %p", (void*)info.start(), (void*)info.end());
      return patchInRegion(libStart, info.end());
    }
  }

  return false;
}

int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSLog(@"Started");

  if (patchFramework()) {
    CPProfileManager *mgr = [CPProfileManager sharedProfileManager];
    if (!mgr) {
      NSLog(@"Error creating CPProfileManager");
      goto cleanup;
    }
    NSLog(@"mgr = %@", mgr);

    getAllProfiles(mgr);
  } else {
    NSLog(@"Could not patch our path");
  }

cleanup:
  NSLog(@"Finished");
  [pool drain];
  return 0;
}

#include "util.h"

#include <string.h>
#include <unistd.h>

#include <Security/Security.h>


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

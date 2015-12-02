#ifndef UTIL_H
#define UTIL_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

char* getPathForPid(pid_t pid);

#ifdef __cplusplus
}
#endif

#endif // UTIL_H

#ifndef LOADED_LIBRARIES_H
#define LOADED_LIBRARIES_H

#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

#include <dlfcn.h>          // for dlsym()
#include <limits.h>         // for PATH_MAX
#include <stdlib.h>         // for realpath()
#include <mach-o/dyld_images.h>
#include <mach/mach.h>


class LibraryInfo {
private:
  const struct dyld_image_info* info_;

public:
  explicit LibraryInfo(const dyld_image_info* info)
    : info_(info) {}

  // Accessors
  uintptr_t imageLoadAddress() const { return (uintptr_t)info_->imageLoadAddress; }
  const char* imageFilePath() const  { return info_->imageFilePath; }

  // Helpful accessor
  std::string realImageFilePath() const {
    char realPath[PATH_MAX] = {0};

    if (realpath(info_->imageFilePath, realPath)) {
      return std::string(realPath);
    }

    return std::string(info_->imageFilePath);
  }

public:
  static std::vector<LibraryInfo> getAll() {
    std::vector<LibraryInfo> ret;

    // Get function pointer that lists all images in this process.
    dyld_all_image_infos *(*dyld_get_all_image_infos)(void);
    dyld_get_all_image_infos = (dyld_all_image_infos*(*)()) dlsym(RTLD_DEFAULT, "_dyld_get_all_image_infos");

    auto allInfos = dyld_get_all_image_infos();
    for (uint32_t i = 0; i < allInfos->infoArrayCount; i++) {
      ret.emplace_back(&allInfos->infoArray[i]);
    }

    // Sort based on start address.
    std::sort(ret.begin(), ret.end(), [](LibraryInfo& a, LibraryInfo& b) {
      return a.imageLoadAddress() < b.imageLoadAddress();
    });

    return ret;
  }
};

#endif

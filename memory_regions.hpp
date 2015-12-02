#ifndef MEMORY_REGIONS_H
#define MEMORY_REGIONS_H

#include <algorithm>
#include <cstdint>
#include <string>
#include <utility>          // for std::forward
#include <vector>

#include <limits.h>         // for PATH_MAX
#include <stdlib.h>         // for realpath()
#include <unistd.h>         // for getpid()
#include <libproc.h>        // for proc_regionfilename
#include <mach/mach.h>

#include <boost/format.hpp>


class RegionInfo {
private:
  vm_address_t                    start_;
  vm_size_t                       size_;
  unsigned int                    depth_;
  vm_region_submap_info_data_64_t info_;

public:
  RegionInfo(vm_address_t start, vm_size_t size, unsigned int depth, vm_region_submap_info_data_64_t& info)
    : start_(start), size_(size), depth_(depth), info_(info) {}

  // Accessors
  vm_address_t start() const { return start_; }
  vm_address_t end() const   { return start_ + size_; }
  vm_size_t    size() const  { return size_; }
  unsigned int depth() const { return depth_; }

  const vm_region_submap_info_data_64_t& info() const {
    return info_;
  }
  
  const char* modeName() const {
    switch (info_.share_mode) {
      case SM_COW:              return "cow";
      case SM_PRIVATE:	        return "private";
      case SM_EMPTY:	        return "null";
      case SM_SHARED:	        return "shared";
      case SM_TRUESHARED:       return "shared";
      case SM_PRIVATE_ALIASED:  return "private_aliased";
      case SM_SHARED_ALIASED:   return "shared_aliased";
      default:	                return "unknown";
    }
  }

  std::string regionFilename() const {
    char filename[PATH_MAX] = {0};
    char realFilename[PATH_MAX] = {0};

    int bytes = proc_regionfilename(
        getpid(),
        (uint64_t)start_,
        filename,
        sizeof(filename)
        );

    if (bytes == 0 || filename[0] == 0) {
      return "";
    }

    if (realpath(filename, realFilename)) {
      return std::string(realFilename);
    }

    return std::string(filename);
  }

  std::string displaySize() const {
    char scale = 'K';
    size_t ds = size_ / 1024;

    if (ds > 99999) {
      scale = 'M';
      ds /= 1024;
    }

    if (ds > 99999) {
      scale = 'G';
      ds /= 1024;
    }

    return (boost::format("%5u%c") % ds % scale).str();
  }

  std::string perms() const {
    char perms[5] = {0};
    sprintf(perms,
        "%c%c%c",
        (info_.protection & VM_PROT_READ) ? 'r' : '-',
        (info_.protection & VM_PROT_WRITE) ? 'w' : '-',
        (info_.protection & VM_PROT_EXECUTE) ? 'x' : '-');

    return perms;
  }

  std::string maxPerms() const {
    char perms[5] = {0};
    sprintf(perms,
        "%c%c%c",
        (info_.max_protection & VM_PROT_READ) ? 'r' : '-',
        (info_.max_protection & VM_PROT_WRITE) ? 'w' : '-',
        (info_.max_protection & VM_PROT_EXECUTE) ? 'x' : '-');

    return perms;
  }

public:
  static std::vector<RegionInfo> getAll(mach_port_name_t target, bool getSubregions = true) {
    std::vector<RegionInfo> ret;
    vm_address_t addr = 0;
    uint32_t depth = 0;

    while (true) {
      vm_region_submap_info_data_64_t info;
      mach_msg_type_number_t info_count = VM_REGION_SUBMAP_INFO_COUNT_64;
      kern_return_t status;

      vm_size_t size = 0;
      status = vm_region_recurse_64(
          target, &addr, &size, &depth, (vm_region_info_t)&info, &info_count);
      if (status == KERN_INVALID_ADDRESS) break;

      // If we hit a submap, we recurse into it.
      if (info.is_submap && getSubregions) {
        depth++;
        continue;
      }

      ret.emplace_back(addr, size, depth, info);
      addr += size;
    }

    // Sort based on start address.
    std::sort(ret.begin(), ret.end(), [](RegionInfo& a, RegionInfo& b) {
      return a.start() < b.start();
    });

    return ret;
  }
};

#endif

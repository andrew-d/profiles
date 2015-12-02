#include "loaded_libraries.hpp"
#include "memory_regions.hpp"

#include <iostream>
#include <string>


int main(void) {
  auto allLibs = LibraryInfo::getAll();

  std::cout << "LIBS\n--------------------------------------------------" << std::endl;
  for (const auto& lib : allLibs) {
    std::cout << "[" << boost::format("%16lx") % lib.imageLoadAddress() << "] "
              << lib.realImageFilePath()
              << std::endl;
  }

  std::cout << "\nREGIONS\n--------------------------------------------------" << std::endl;
  auto regions = RegionInfo::getAll(mach_task_self());

  for (const auto& info : regions) {
    std::cout << boost::format("%16lx") % info.start()
              << " - "
              << boost::format("%-16lx") % info.end()
              << " [" << info.displaySize() << "] "
              << info.perms() << "/" << info.maxPerms() << " ";

    auto fname = info.regionFilename();
    if (fname.size() > 0) {
      std::cout << fname;
    } else {
      std::cout << "[" << info.modeName() << "]";
    }

    std::cout << std::endl;
  }

  std::cerr << "Done" << std::endl;
  return 0;
}

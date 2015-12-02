CC := gcc
CXX := g++

CPPFLAGS := -g -Wall -Wextra
CXXFLAGS := -std=c++11
OBJCFLAGS :=

LIBS :=
LDFLAGS := $(LIBS)

OBJC_LIBS := -lobjc
FRAMEWORKS := -framework Foundation -framework ConfigurationProfiles -framework Security
OBJC_LDFLAGS := $(LDFLAGS) -F/System/Library/PrivateFrameworks $(FRAMEWORKS) $(OBJC_LIBS)

HEADERS := \
    $(shell find . -name '*.hpp') \
    $(shell find . -name '*.h')

##################################################
## TARGETS

all: get_images profiles

get_images: get_images.o
	$(CXX) -o $@ $(LDFLAGS) $^

profiles: profiles.o
	$(CXX) -o $@ $(OBJC_LDFLAGS) $^


##################################################
## OBJECTS

get_images.o: get_images.cpp $(HEADERS)
	$(CXX) -c -o $@ $(CPPFLAGS) $(CXXFLAGS) $<

profiles.o: profiles.mm $(HEADERS)
	$(CXX) -c -o $@ $(CPPFLAGS) $(CXXFLAGS) $(OBJCFLAGS) $<


##################################################
## DEBUGGING & UTILITY

.PHONY: env
env:
	@echo "CPPFLAGS     = $(CPPFLAGS)"
	@echo "CXXFLAGS     = $(CXXFLAGS)"
	@echo "OBJCFLAGS    = $(OBJCFLAGS)"
	@echo "LIBS         = $(LIBS)"
	@echo "LDFLAGS      = $(LDFLAGS)"
	@echo "OBJC_LIBS    = $(OBJC_LIBS)"
	@echo "FRAMEWORKS   = $(FRAMEWORKS)"
	@echo "OBJC_LDFLAGS = $(OBJC_LDFLAGS)"
	@echo "HEADERS      = $(HEADERS)"

.PHONY: clean
clean:
	$(RM) *.o get_images profiles

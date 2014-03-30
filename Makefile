# The makefile for caffe. Extremely hacky.
PROJECT := caffe

include Makefile.config

##############################################################################
# After this line, things should happen automatically.
##############################################################################

# The target static library and shared library name
NAME := lib$(PROJECT).so
STATIC_NAME := lib$(PROJECT).a

##############################
# Get all source files
##############################
# CXX_SRCS are the source files excluding the test ones.
CXX_SRCS := $(shell find src/$(PROJECT) ! -name "test_*.cpp" -name "*.cpp")
# HXX_SRCS are the header files
HXX_SRCS := $(shell find include/$(PROJECT) ! -name "*.hpp")
# CU_SRCS are the cuda source files
CU_SRCS := $(shell find src/$(PROJECT) -name "*.cu")
# TEST_SRCS are the test source files
TEST_MAIN_SRC := src/$(PROJECT)/test/test_caffe_main.cpp
TEST_SRCS := $(shell find src/$(PROJECT) -name "test_*.cpp")
TEST_SRCS := $(filter-out $(TEST_MAIN_SRC), $(TEST_SRCS))
GTEST_SRC := src/gtest/gtest-all.cpp
# TEST_HDRS are the test header files
TEST_HDRS := $(shell find src/$(PROJECT) -name "test_*.hpp")
# TOOL_SRCS are the source files for the tool binaries
TOOL_SRCS := $(shell find tools -name "*.cpp")
# EXAMPLE_SRCS are the source files for the example binaries
EXAMPLE_SRCS := $(shell find examples -name "*.cpp")
# BUILD_INCLUDE_DIR contains any generated header files we want to include.
BUILD_INCLUDE_DIR := $(BUILD_DIR)/include
# PROTO_SRCS are the protocol buffer definitions
PROTO_SRC_DIR := src/$(PROJECT)/proto
PROTO_SRCS := $(wildcard $(PROTO_SRC_DIR)/*.proto)
# PROTO_BUILD_DIR will contain the .cc and obj files generated from
# PROTO_SRCS; PROTO_BUILD_INCLUDE_DIR will contain the .h header files
PROTO_BUILD_DIR := $(BUILD_DIR)/$(PROTO_SRC_DIR)
PROTO_BUILD_INCLUDE_DIR := $(BUILD_INCLUDE_DIR)/$(PROJECT)/proto
# NONGEN_CXX_SRCS includes all source/header files except those generated
# automatically (e.g., by proto).
NONGEN_CXX_SRCS := $(shell find \
	src/$(PROJECT) \
	include/$(PROJECT) \
	python/$(PROJECT) \
	matlab/$(PROJECT) \
	examples \
	tools \
	-name "*.cpp" -or -name "*.hpp" -or -name "*.cu" -or -name "*.cuh")
LINT_REPORT := $(BUILD_DIR)/cpp_lint.log
FAILED_LINT_REPORT := $(BUILD_DIR)/cpp_lint.error_log
# PY$(PROJECT)_SRC is the python wrapper for $(PROJECT)
PY$(PROJECT)_SRC := python/$(PROJECT)/_$(PROJECT).cpp
PY$(PROJECT)_SO := python/$(PROJECT)/_$(PROJECT).so
# MAT$(PROJECT)_SRC is the matlab wrapper for $(PROJECT)
MAT$(PROJECT)_SRC := matlab/$(PROJECT)/mat$(PROJECT).cpp
MAT$(PROJECT)_SO := matlab/$(PROJECT)/$(PROJECT)

##############################
# Derive generated files
##############################
# The generated files for protocol buffers
PROTO_GEN_HEADER := $(addprefix $(PROTO_BUILD_INCLUDE_DIR)/, \
	$(notdir ${PROTO_SRCS:.proto=.pb.h}))
HXX_SRCS += $(PROTO_GEN_HEADER)
PROTO_GEN_CC := $(addprefix $(BUILD_DIR)/, ${PROTO_SRCS:.proto=.pb.cc})
PROTO_GEN_PY := ${PROTO_SRCS:.proto=_pb2.py}
# The objects corresponding to the source files
# These objects will be linked into the final shared library, so we
# exclude the tool, example, and test objects.
CXX_OBJS := $(addprefix $(BUILD_DIR)/, ${CXX_SRCS:.cpp=.o})
CU_OBJS := $(addprefix $(BUILD_DIR)/, ${CU_SRCS:.cu=.cuo})
PROTO_OBJS := ${PROTO_GEN_CC:.cc=.o}
OBJS := $(PROTO_OBJS) $(CXX_OBJS) $(CU_OBJS)
# tool, example, and test objects
TOOL_OBJS := $(addprefix $(BUILD_DIR)/, ${TOOL_SRCS:.cpp=.o})
EXAMPLE_OBJS := $(addprefix $(BUILD_DIR)/, ${EXAMPLE_SRCS:.cpp=.o})
TEST_OBJS := $(addprefix $(BUILD_DIR)/, ${TEST_SRCS:.cpp=.o})
GTEST_OBJ := $(addprefix $(BUILD_DIR)/, ${GTEST_SRC:.cpp=.o})
# tool, example, and test bins
TOOL_BINS := ${TOOL_OBJS:.o=.bin}
EXAMPLE_BINS := ${EXAMPLE_OBJS:.o=.bin}
TEST_BINS := ${TEST_OBJS:.o=.testbin}
TEST_BUILD_SUB_DIR := src/$(PROJECT)/test
TEST_DIR = $(BUILD_DIR)/$(TEST_BUILD_SUB_DIR)
TEST_ALL_BIN := $(TEST_DIR)/test_all.testbin
# A shortcut to the directory of test binaries for convenience.
TEST_DIR_LINK := $(BUILD_DIR)/test

##############################
# Derive include and lib directories
##############################
CUDA_INCLUDE_DIR := $(CUDA_DIR)/include
CUDA_LIB_DIR := $(CUDA_DIR)/lib64 $(CUDA_DIR)/lib
MKL_INCLUDE_DIR := $(MKL_DIR)/include
MKL_LIB_DIR := $(MKL_DIR)/lib $(MKL_DIR)/lib/intel64

INCLUDE_DIRS += ./src ./include $(CUDA_INCLUDE_DIR)
INCLUDE_DIRS += $(BUILD_INCLUDE_DIR)
LIBRARY_DIRS += $(CUDA_LIB_DIR)
LIBRARIES := cudart cublas curand \
	pthread \
	glog protobuf leveldb snappy \
	boost_system \
	hdf5_hl hdf5 \
	opencv_core opencv_highgui opencv_imgproc
PYTHON_LIBRARIES := boost_python python2.7
WARNINGS := -Wall

ifdef DEBUG
	COMMON_FLAGS := -DDEBUG -g -O0
else
	COMMON_FLAGS := -DNDEBUG -O2
endif

# MKL switch (default = non-MKL)
USE_MKL ?= 0
ifeq ($(USE_MKL), 1)
  LIBRARIES += mkl_rt
  COMMON_FLAGS += -DUSE_MKL
  INCLUDE_DIRS += $(MKL_INCLUDE_DIR)
  LIBRARY_DIRS += $(MKL_LIB_DIR)
else
  LIBRARIES += cblas atlas
endif

COMMON_FLAGS += $(foreach includedir,$(INCLUDE_DIRS),-I$(includedir))
CXXFLAGS += -pthread -fPIC $(COMMON_FLAGS)
NVCCFLAGS := -ccbin=$(CXX) -Xcompiler -fPIC $(COMMON_FLAGS)
LDFLAGS += $(foreach librarydir,$(LIBRARY_DIRS),-L$(librarydir)) \
		$(foreach library,$(LIBRARIES),-l$(library))
PYTHON_LDFLAGS := $(LDFLAGS) $(foreach library,$(PYTHON_LIBRARIES),-l$(library))

##############################
# Define build targets
##############################
.PHONY: all init test clean linecount lint tools examples distribute \
	py mat py$(PROJECT) mat$(PROJECT) proto runtest \
	superclean supercleanlist supercleanfiles \
	testshortcut

all: init $(NAME) $(STATIC_NAME) tools examples
	@echo $(CXX_OBJS)

init:
	@ mkdir -p $(foreach obj,$(OBJS),$(dir $(obj)))
	@ mkdir -p $(foreach obj,$(TOOL_OBJS),$(dir $(obj)))
	@ mkdir -p $(foreach obj,$(EXAMPLE_OBJS),$(dir $(obj)))
	@ mkdir -p $(foreach obj,$(TEST_OBJS),$(dir $(obj)))
	@ mkdir -p $(foreach obj,$(GTEST_OBJ),$(dir $(obj)))

linecount: clean
	cloc --read-lang-def=$(PROJECT).cloc src/$(PROJECT)/

lint: $(LINT_REPORT)

$(LINT_REPORT): $(NONGEN_CXX_SRCS)
	@ mkdir -p $(BUILD_DIR)
	@ (python ./scripts/cpp_lint.py $(NONGEN_CXX_SRCS) > $(LINT_REPORT) 2>&1 \
		&& (rm -f $(FAILED_LINT_REPORT); echo "No lint errors!")) || ( \
			mv $(LINT_REPORT) $(FAILED_LINT_REPORT); \
			grep -v "^Done processing " $(FAILED_LINT_REPORT); \
			echo "Found 1 or more lint errors; see log at $(FAILED_LINT_REPORT)"; \
			exit 1)

test: init $(TEST_BINS) $(TEST_ALL_BIN)

tools: init proto $(TOOL_BINS)

examples: init $(EXAMPLE_BINS)

py$(PROJECT): py

py: init $(STATIC_NAME) $(PY$(PROJECT)_SRC) $(PROTO_GEN_PY)
	$(CXX) -shared -o $(PY$(PROJECT)_SO) $(PY$(PROJECT)_SRC) \
		$(STATIC_NAME) $(CXXFLAGS) $(PYTHON_LDFLAGS)
	@echo

mat$(PROJECT): mat

mat: init $(STATIC_NAME) $(MAT$(PROJECT)_SRC)
	$(MATLAB_DIR)/bin/mex $(MAT$(PROJECT)_SRC) $(STATIC_NAME) \
		CXXFLAGS="\$$CXXFLAGS $(CXXFLAGS) $(WARNINGS)" \
		CXXLIBS="\$$CXXLIBS $(LDFLAGS)" \
		-o $(MAT$(PROJECT)_SO)
	@echo

$(NAME): init $(PROTO_OBJS) $(OBJS)
	$(CXX) -shared -o $(NAME) $(OBJS) $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@echo

$(STATIC_NAME): init $(PROTO_OBJS) $(OBJS)
	ar rcs $(STATIC_NAME) $(PROTO_OBJS) $(OBJS)
	@echo

runtest: $(TEST_ALL_BIN)
	$(TEST_ALL_BIN) $(TEST_GPUID)

$(BUILD_DIR)/src/$(PROJECT)/test/%.testbin: \
		$(BUILD_DIR)/src/$(PROJECT)/test/%.o \
		$(GTEST_OBJ) $(STATIC_NAME) testshortcut
	$(CXX) $(TEST_MAIN_SRC) $< $(GTEST_OBJ) $(STATIC_NAME) \
		-o $@ $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)

$(TEST_ALL_BIN): $(GTEST_OBJ) $(STATIC_NAME) $(TEST_OBJS) testshortcut
	$(CXX) $(TEST_MAIN_SRC) $(TEST_OBJS) $(GTEST_OBJ) $(STATIC_NAME) \
		-o $(TEST_ALL_BIN) $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)

testshortcut: | $(TEST_DIR_LINK)

$(TEST_DIR_LINK): | $(TEST_DIR)
	ln -s $(TEST_BUILD_SUB_DIR) $(TEST_DIR_LINK)

$(TEST_DIR):
	mkdir -p $(TEST_DIR)

$(TOOL_BINS): %.bin : %.o $(STATIC_NAME)
	$(CXX) $< $(STATIC_NAME) -o $@ $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@echo

$(EXAMPLE_BINS): %.bin : %.o $(STATIC_NAME)
	$(CXX) $< $(STATIC_NAME) -o $@ $(CXXFLAGS) $(LDFLAGS) $(WARNINGS)
	@echo

$(BUILD_DIR)/src/$(PROJECT)/%.o: src/$(PROJECT)/%.cpp
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@echo

$(OBJS): $(PROTO_GEN_HEADER) $(HXX_SRCS)
	@echo matched the first objs!!


LAYERS_DIR := $(BUILD_DIR)/src/$(PROJECT)/layers
$(LAYERS_DIR):
	@ mkdir -p $(LAYERS_DIR)

$(BUILD_DIR)/src/$(PROJECT)/layers/%.o: \
		src/$(PROJECT)/layers/%.cpp $(HXX_SRCS) | $(LAYERS_DIR)
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@echo

$(BUILD_DIR)/src/$(PROJECT)/proto/%.o: src/$(PROJECT)/proto/%.cc src/$(PROJECT)/proto/%.h
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@echo

$(BUILD_DIR)/src/$(PROJECT)/test/%.o: $(PROTO_GEN_HEADER) src/$(PROJECT)/test/%.cpp
	$(CXX) $< $(CXXFLAGS) -c -o $@

$(BUILD_DIR)/src/$(PROJECT)/util/%.o: src/$(PROJECT)/util/%.cpp
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@echo

$(BUILD_DIR)/src/gtest/%.o: src/gtest/%.cpp
	$(CXX) $< $(CXXFLAGS) -c -o $@
	@echo

$(BUILD_DIR)/src/$(PROJECT)/layers/%.cuo: src/$(PROJECT)/layers/%.cu
	$(CUDA_DIR)/bin/nvcc $(NVCCFLAGS) $(CUDA_ARCH) -c $< -o $@
	@echo

$(BUILD_DIR)/src/$(PROJECT)/util/%.cuo: src/$(PROJECT)/util/%.cu
	$(CUDA_DIR)/bin/nvcc $(NVCCFLAGS) $(CUDA_ARCH) -c $< -o $@
	@echo

$(BUILD_DIR)/tools/%.o: tools/%.cpp $(PROTO_GEN_HEADER)
	$(CXX) $< $(CXXFLAGS) -c -o $@ $(LDFLAGS)
	@echo

$(BUILD_DIR)/examples/%.o: examples/%.cpp $(PROTO_GEN_HEADER)
	$(CXX) $< $(CXXFLAGS) -c -o $@ $(LDFLAGS)
	@echo

$(PROTO_GEN_PY): $(PROTO_SRCS)
	protoc --proto_path=src --python_out=python $(PROTO_SRCS)
	@echo

proto: init $(PROTO_GEN_CC) $(PROTO_GEN_HEADER)
	@echo PROTO_GEN_CC: $(PROTO_GEN_CC)
	@echo PROTO_GEN_HEADER: $(PROTO_GEN_HEADER)
	@echo PROTO_OBJS: $(PROTO_OBJS)

$(PROTO_BUILD_DIR)/%.pb.cc $(PROTO_BUILD_DIR)/%.pb.h \
		$(PROTO_BUILD_INCLUDE_DIR)/%.pb.h: \
		$(PROTO_SRC_DIR)/%.proto | $(PROTO_BUILD_DIR) $(PROTO_BUILD_INCLUDE_DIR)
	protoc --proto_path=src --cpp_out=build/src $<
	cp $(PROTO_BUILD_DIR)/$(*F).pb.h $(PROTO_BUILD_INCLUDE_DIR)/$(*F).pb.h

$(PROTO_BUILD_DIR):
	mkdir -p $(PROTO_BUILD_DIR)

$(PROTO_BUILD_INCLUDE_DIR):
	mkdir -p $(PROTO_BUILD_INCLUDE_DIR)

clean:
	@- $(RM) $(NAME) $(STATIC_NAME)
	@- $(RM) $(PROTO_GEN_HEADER) $(PROTO_GEN_CC) $(PROTO_GEN_PY)
	@- $(RM) include/$(PROJECT)/proto/$(PROJECT).pb.h
	@- $(RM) python/$(PROJECT)/proto/$(PROJECT)_pb2.py
	@- $(RM) python/$(PROJECT)/*.so
	@- $(RM) -rf $(BUILD_DIR)
	@- $(RM) -rf $(DISTRIBUTE_DIR)

# make superclean recursively* deletes all files ending with an extension
# suggesting that Caffe built them.  This may be useful if you've built older
# versions of Caffe that do not place all generated files in a location known
# to make clean.
#
# make supercleanlist will list the files to be deleted by make superclean.
#
# * Recursive with the exception that symbolic links are never followed, per the
# default behavior of 'find'.
SUPERCLEAN_EXTS := .so .a .o .bin .testbin .pb.cc .pb.h _pb2.py .cuo

supercleanfiles:
	$(eval SUPERCLEAN_FILES := $(strip \
		$(foreach ext,$(SUPERCLEAN_EXTS), $(shell find . -name '*$(ext)'))))

supercleanlist: supercleanfiles
	@ \
	if [ -z "$(SUPERCLEAN_FILES)" ]; then \
	  echo "No generated files found."; \
	else \
	  echo $(SUPERCLEAN_FILES) | tr ' ' '\n'; \
	fi

superclean: clean supercleanfiles
	@ \
	if [ -z "$(SUPERCLEAN_FILES)" ]; then \
	  echo "No generated files found."; \
	else \
	  echo "Deleting the following generated files:"; \
	  echo $(SUPERCLEAN_FILES) | tr ' ' '\n'; \
	  $(RM) $(SUPERCLEAN_FILES); \
	fi

distribute: all
	mkdir $(DISTRIBUTE_DIR)
	# add include
	cp -r include $(DISTRIBUTE_DIR)/
	# add tool and example binaries
	mkdir $(DISTRIBUTE_DIR)/bin
	cp $(TOOL_BINS) $(DISTRIBUTE_DIR)/bin
	cp $(EXAMPLE_BINS) $(DISTRIBUTE_DIR)/bin
	# add libraries
	mkdir $(DISTRIBUTE_DIR)/lib
	cp $(NAME) $(DISTRIBUTE_DIR)/lib
	cp $(STATIC_NAME) $(DISTRIBUTE_DIR)/lib
	# add python - it's not the standard way, indeed...
	cp -r python $(DISTRIBUTE_DIR)/python

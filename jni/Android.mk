ifndef TARGET_PROTOBUF_ROOT
    $(error "TARGET_PROTOBUF_ROOT is not defined")
endif
ifndef HOST_PROTOBUF_ROOT
    $(error "HOST_PROTOBUF_ROOT is not defined")
endif

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := protobuf-prebuilt
LOCAL_SRC_FILES := $(TARGET_PROTOBUF_ROOT)-$(TARGET_ARCH_ABI)/lib/libprotobuf.a
$(info $(LOCAL_SRC_FILES))
LOCAL_EXPORT_C_INCLUDES := $(TARGET_PROTOBUF_ROOT)-$(TARGET_ARCH_ABI)/include
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
$(shell (rm -rf $(LOCAL_PATH)/src $(LOCAL_PATH)/third_party))
$(shell (cp -rf src $(LOCAL_PATH)/src))
$(shell (cp -rf third_party $(LOCAL_PATH)/third_party))

LOCAL_PROTOC := $(HOST_PROTOBUF_ROOT)/bin/protoc
LOCAL_MODULE := sentencepiece
LOCAL_PROTO_SRCS := $(wildcard src/*.proto)
LOCAL_PROTO_CC_SRCS := $(LOCAL_PROTO_SRCS:.proto=.pb.cc)

$(foreach proto,$(LOCAL_PROTO_SRCS),$(shell ($(LOCAL_PROTOC) $(proto) --cpp_out $(LOCAL_PATH)));)

LOCAL_CC_ALL_SRCS := $(sort $(wildcard src/*.cc))
LOCAL_CC_EXCLUDE_SRCS := \
	$(wildcard src/*test.cc) \
	$(wildcard src/test*.cc) \
	$(wildcard src/*main.cc) \
	$(wildcard src/*trainer.cc) \
	$(wildcard src/trainer*.cc) \
	$(wildcard src/*script.cc) \
	$(wildcard src/builder.cc) \
	$(wildcard src/flags.cc)
LOCAL_SRC_FILES := $(filter-out $(LOCAL_CC_EXCLUDE_SRCS), $(LOCAL_CC_ALL_SRCS)) $(LOCAL_PROTO_CC_SRCS)
LOCAL_CPP_EXTENSION := .cc
LOCAL_C_INCLUDES := src third_party/darts_clone
LOCAL_CFLAGS += --std=c++11 -fPIC
LOCAL_CPP_FEATURES := rtti exceptions
LOCAL_LDLIBS += -llog -lz -lm 
LOCAL_STATIC_LIBRARIES := protobuf-prebuilt
include $(BUILD_SHARED_LIBRARY)

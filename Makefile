PONYC ?= ponyc
PONYC_FLAGS ?=--checktree --verify
config ?= release

BUILD_DIR ?= build/$(config)
SRC_DIR ?= websocket
EXAMPLES_DIR ?= examples

SOURCE_FILES := $(shell find $(SRC_DIR) -name \*.pony)
EXAMPLES_SOURCE_FILES := $(shell find $(EXAMPLES_DIR) -name \*.pony)

OPENSSL_VERSION ?= openssl_1.1.x

ifdef config
  ifeq (,$(filter $(config),debug release))
    $(error Unknown configuration "$(config)")
  endif
endif

ifeq ($(config),debug)
    PONYC_FLAGS += --debug
endif


$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

examples: $(SOURCE_FILES) $(EXAMPLES_SOURCE_FILES) | $(BUILD_DIR)
	corral fetch
	corral run -- $(PONYC) -D$(OPENSSL_VERSION) --path=. $(EXAMPLES_DIR)/broadcast   -o $(BUILD_DIR) $(PONYC_FLAGS)
	corral run -- $(PONYC) -D$(OPENSSL_VERSION) --path=. $(EXAMPLES_DIR)/echo-server -o $(BUILD_DIR) $(PONYC_FLAGS)
	corral run -- $(PONYC) -D$(OPENSSL_VERSION) --path=. $(EXAMPLES_DIR)/simple-echo -o $(BUILD_DIR) $(PONYC_FLAGS)
	corral run -- $(PONYC) -D$(OPENSSL_VERSION) --path=. $(EXAMPLES_DIR)/ssl-echo    -o $(BUILD_DIR) $(PONYC_FLAGS)

clean:
	rm -rf $(BUILD_DIR) .coverage

test:
	docker run -it --rm \
	  -v ${PWD}/tests:/config \
	  -v ${PWD}/reports:/reports \
	  --network host \
	  --name fuzzingclient \
	  crossbario/autobahn-testsuite \
	 /opt/pypy/bin/wstest --mode fuzzingclient --spec /config/fuzzingclient.json

.PHONY: clean examples test

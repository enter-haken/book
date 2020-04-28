.PHONY: default
default: build

install_node_modules_if_neccessary:
		if [ ! -d node_modules/ ]; then npm install; fi

.PHONY: build
build: install_node_modules_if_neccessary
	npm run css-build

.PHONY: clean
clean:
	rm css/ -rf || true

.PHONY: deep_clean
deep_clean: clean
	rm node_modules/ -rf || true


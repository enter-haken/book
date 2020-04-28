.PHONY: default
default: build

.PHONY: check_deps
check_deps:
	if [ ! -d deps ]; then mix deps.get; fi

.PHONY: create_css_if_necessary
create_css_if_necessary:
	if [ ! -d priv/styles/css ]; then make -C priv/styles/ build; fi

.PHONY: build
build: check_deps clean_generated create_css_if_necessary
	mix book.generate
	mix compile --force --warnings-as-errors

.PHONY: run
run: build
	MIX_ENV=dev iex -S mix

.PHONY: clean
clean:
	rm doc/ -rf || true
	rm _build/ -rf || true

.PHONY: clean_generated
clean_generated:
	rm priv/generated/ -rf || true
	rm priv/tests/ -rf || true

.PHONY: clean_modules
clean_modules:
	rm deps/ -rf || true

.PHONY: deep_clean
deep_clean: clean clean_modules clean_generated
	make -C priv/styles deep_clean

.PHONY: test
test: check_deps
	mix test --trace

.PHONY: loc
loc:
	find lib -type f | while read line; do cat $$line; done | sed '/^\s*$$/d' | wc -l

.PHONY: release
release: build
	MIX_ENV=prod mix release

.PHONY: docker
docker: 
	docker build -t book .

.PHONY: docker_run
docker_run:
	docker run \
		-p 5051:4050 \
		--name book \
		-d \
		-t book 

.PHONY: update
update:
	docker stop book
	docker rm book
	docker rmi book
	make docker docker_run

.PHONY: ignore
ignore:
	find deps/ > .ignore || true
	find doc/ >> .ignore || true
	find _build/ >> .ignore || true
	find priv/styles/node_modules/ >> .ignore || true
	find priv/styles/css/ >> .ignore || true
	find priv/generated/ >> .ignore || true

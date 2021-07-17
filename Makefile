VERSION := `cat VERSION`

CURRENT := book:${VERSION}
DOCKERHUB_TARGET := enterhaken/book:${VERSION}
DOCKERHUB_TARGET_LATEST := enterhaken/book:latest

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
	docker build -t ${CURRENT} .

.PHONY: docker_push
docker_push:
	docker tag $(CURRENT) $(DOCKERHUB_TARGET)
	docker push $(DOCKERHUB_TARGET)
	docker tag $(CURRENT) $(DOCKERHUB_TARGET_LATEST)
	docker push $(DOCKERHUB_TARGET_LATEST)

.PHONY: docker_run
docker_run:
	docker run \
		-p 5051:4050 \
		--name book \
		-d \
		-t ${LATEST} 

.PHONY: update
update: docker
	docker stop book
	docker rm book 
	make docker_run

.PHONY: ignore
ignore:
	find deps/ > .ignore || true
	find doc/ >> .ignore || true
	find _build/ >> .ignore || true

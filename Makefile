REPO=malice-plugins/comodo
ORG=malice
NAME=comodo
VERSION=$(shell cat VERSION)

all: build size test avtest gotest

build:
	docker build -t $(ORG)/$(NAME):$(VERSION) .

base:
	docker build -f Dockerfile.base -t $(REORGPO)/$(NAME):base .

dev: test
	docker build -f Dockerfile.dev -t $(ORG)/$(NAME):$(VERSION) .

size:
	sed -i.bu 's/docker%20image-.*-blue/docker%20image-$(shell docker images --format "{{.Size}}" $(ORG)/$(NAME):$(VERSION)| cut -d' ' -f1)-blue/' README.md

tags:
	docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" $(ORG)/$(NAME)

tar:
	docker save $(ORG)/$(NAME):$(VERSION) -o $(NAME).tar

gotest:
	go get
	go test -v

avtest:
	@echo "===> Comodo Version"
	@docker run --init --rm --entrypoint=bash $(ORG)/$(NAME):$(VERSION) -c "/opt/COMODO/cmdscan -h" > tests/av_version.out
	@echo "===> Comodo EICAR Test"
	@docker run --init --rm --entrypoint=bash $(ORG)/$(NAME):$(VERSION) -c "/opt/COMODO/cmdscan -vs /malware/EICAR" > tests/av_scan.out || true

update:
	@docker run  --rm $(ORG)/$(NAME):$(VERSION) update

test:
	docker run --init -d --name elasticsearch -p 9200:9200 blacktop/elasticsearch
	sleep 10; docker run --init --rm $(ORG)/$(NAME):$(VERSION)
	docker run --init --rm --link elasticsearch $(ORG)/$(NAME):$(VERSION) -V EICAR | jq . > docs/results.json
	cat docs/results.json | jq .
	http localhost:9200/malice/_search | jq . > docs/elastic.json
	cat docs/elastic.json | jq -r '.hits.hits[] ._source.plugins.av.${NAME}.markdown' > docs/SAMPLE.md
	docker rm -f elasticsearch

circle:
	@http https://circleci.com/api/v1.1/project/github/${REPO} | jq '.[0].build_num' > .circleci/build_num \
		&& http "$(shell http https://circleci.com/api/v1.1/project/github/${REPO}/$(shell cat .circleci/build_num)/artifacts${CIRCLE_TOKEN} | jq '.[].url')" > .circleci/SIZE \
		&& sed -i.bu 's/docker%20image-.*-blue/docker%20image-$(shell cat .circleci/SIZE)-blue/' README.md
	@echo "===> Image size is: $(shell cat .circleci/SIZE)"

clean:
	docker-clean stop
	docker rmi $(ORG)/$(NAME):$(VERSION)
	docker rmi $(ORG)/$(NAME):base

.PHONY: build dev size tags test gotest clean

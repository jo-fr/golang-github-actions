FROM golang:1.18

ENV GO111MODULE=on

RUN apt-get update && \
	apt-get -y install jq && \
	go install github.com/kisielk/errcheck@latest && \
	go install golang.org/x/tools/cmd/goimports@latest && \
	go install golang.org/x/lint/golint@latest && \
	curl -sfL https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v2.12.0 && \
	go install golang.org/x/tools/go/analysis/passes/shadow/cmd/shadow@latest && \
	go install honnef.co/go/tools/cmd/staticcheck@latest && \
	go install github.com/client9/misspell/cmd/misspell@latest && \
	go install github.com/gordonklaus/ineffassign@latest


COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

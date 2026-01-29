FROM golang:1.25-alpine AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -ldflags='-s -w' -o /usr/local/bin/srotoc ./cmd/srotoc

FROM gcr.io/distroless/static-debian13:nonroot

COPY --from=build /usr/local/bin/srotoc /usr/local/bin/srotoc

ENTRYPOINT ["srotoc"]

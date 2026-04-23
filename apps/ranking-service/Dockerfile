FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /app/ranking-service ./cmd/main.go


FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -S appgroup && adduser -S appuser -G appgroup -u 1001

WORKDIR /app

COPY --from=builder /app/ranking-service .

USER appuser

EXPOSE 8080

ENTRYPOINT ["./ranking-service"]

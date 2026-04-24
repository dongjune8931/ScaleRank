package infrastructure

import (
	"fmt"
	"os"
)

type Config struct {
	Port         string
	DBHost       string
	DBPort       string
	DBUser       string
	DBPassword   string
	DBName       string
	RedisHost    string
	RedisPort    string
	OTelEndpoint string
}

func Load() Config {
	return Config{
		Port:         getEnvOrDefault("PORT", "8080"),
		DBHost:       mustGetEnv("DB_HOST"),
		DBPort:       getEnvOrDefault("DB_PORT", "3306"),
		DBUser:       mustGetEnv("DB_USER"),
		DBPassword:   mustGetEnv("DB_PASSWORD"),
		DBName:       mustGetEnv("DB_NAME"),
		RedisHost:    os.Getenv("REDIS_HOST"),
		RedisPort:    getEnvOrDefault("REDIS_PORT", "6379"),
		OTelEndpoint: os.Getenv("OTEL_ENDPOINT"),
	}
}

func mustGetEnv(key string) string {
	val := os.Getenv(key)
	if val == "" {
		panic(fmt.Sprintf("required environment variable %q is not set", key))
	}
	return val
}

func getEnvOrDefault(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

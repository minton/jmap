import Config

# Configure test environment
config :jmap,
  api_token: "test-token",
  provider: :fastmail

# Disable any real HTTP requests during tests
config :req,
  adapter: Req.Test

# Exclude integration tests by default
config :jmap, :test_exclude, [:integration]

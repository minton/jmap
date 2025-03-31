defmodule Jmap.MixProject do
  use Mix.Project

  @github_url "https://github.com/minton/jmap"

  def project do
    [
      app: :jmap,
      version: "0.0.1",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      name: "JMAP",
      docs: docs()
    ]
  end

  defp package do
    [
      description: "Basic JMAP client library for Elixir",
      maintainers: ["minton"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url
      },
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE*"
      ]
    ]
  end

  defp docs do
    [
      main: "Jmap",
      source_url: @github_url,
      homepage_url: @github_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

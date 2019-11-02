defmodule AuthToken.Mixfile do
  use Mix.Project

  @version "0.3.0"

  @maintainers ["Daniel Khalil"]
  @description """
  Simplified encrypted authentication tokens using JWE.
  """

  @github "https://github.com/Brainsware/authtoken"

  def project do
    [
      name: "AuthToken",
      app: :authtoken,
      version: @version,
      description: @description,
      maintainers: @maintainers,
      source_url: @github,
      homepage_url: "https://sealas.at",
      elixir: "~> 1.9",
      start_permanent: Mix.env == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps(),
      docs: docs(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
    ]
  end

  def application do
    [applications: [:logger, :plug],
    env: [
      timeout: 86400,
      refresh: 1800
    ]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jose, "~> 1.9"},
      {:ojson, "~> 1.0"},
      {:plug, "~> 1.8"},
      {:phoenix, "~> 1.4"},

      {:poison, "~> 1.0", only: :test},
      # {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev},
      # {:excoveralls, "~> 0.12.0", only: [:dev, :test], runtime: false},
    ]
  end

  defp docs do
    [
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      maintainers: @maintainers,
      links: %{github: @github},
      licenses: ["Apache 2.0"],
    ]
  end
end

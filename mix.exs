defmodule SFTPAPI.MixProject do
  use Mix.Project

  def project do
    [
      app: :sftp_api,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {SFTPAPI.Application, []},
      extra_applications: [:logger, :runtime_tools, :ssh]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.9"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:postgrex, ">= 0.0.0"}
    ]
  end

  defp aliases do
    [
      server: ["ecto.create", "ecto.migrate", "run --no-halt"]
    ]
  end

  # Run "mix help docs" to learn about docs
  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end

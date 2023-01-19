defmodule SFTPAPI.MixProject do
  use Mix.Project

  def project do
    [
      app: :sftp_api,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
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

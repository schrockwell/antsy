defmodule Antsy.MixProject do
  use Mix.Project

  def project do
    [
      app: :antsy,
      version: "0.2.1",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Decodes ANSI escape sequences",
      package: package(),
      source_url: "https://github.com/schrockwell/antsy",
      docs: [
        main: "Antsy"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    [
      name: "antsy",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/schrockwell/antsy"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.2.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34.2", only: :dev, runtime: false}
    ]
  end
end

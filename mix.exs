defmodule JsonMergePatch.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/netoum/json_merge_patch"
  @rfc_url "https://datatracker.ietf.org/doc/html/rfc7396"

  def project do
    [
      app: :json_merge_patch,
      name: "JsonMergePatch",
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      test_coverage: [summary: [threshold: 100]]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [],
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp description do
    "RFC 7396 JSON Merge Patch for Elixir."
  end

  defp package do
    [
      licenses: ["MIT"],
      files:
        ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs assets CONTRIBUTING.md CODE_OF_CONDUCT.md),
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "RFC 7396" => @rfc_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"],
        "CONTRIBUTING.md": [title: "Contributing"],
        "CODE_OF_CONDUCT.md": [title: "Code of Conduct"]
      ],
      assets: %{"assets" => "assets"},
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end

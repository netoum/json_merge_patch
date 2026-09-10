# JsonMergePatch

[![CI](https://github.com/netoum/json_merge_patch/actions/workflows/ci.yml/badge.svg)](https://github.com/netoum/json_merge_patch/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/json_merge_patch.svg)](https://hex.pm/packages/json_merge_patch)
[![Hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/json_merge_patch/)

RFC 7396 JSON Merge Patch for Elixir.

Applies a merge patch to decoded JSON values: maps with string keys, lists,
strings, numbers, booleans, and `nil`. Decode with `JSON` or `Jason`, then call
`JsonMergePatch.apply_patch/2`.

```elixir
JsonMergePatch.apply_patch(
  %{"a" => "b", "c" => %{"d" => "e", "f" => "g"}},
  %{"a" => "z", "c" => %{"f" => nil}}
)
# => {:ok, %{"a" => "z", "c" => %{"d" => "e"}}}
```

## Installation

```elixir
def deps do
  [
    {:json_merge_patch, "~> 0.1.0"}
  ]
end
```

## Usage

`JsonMergePatch.apply_patch/2` returns `{:ok, json}` or `{:error, exception}`.
`JsonMergePatch.apply_patch!/2` raises `JsonMergePatch.Error`.

```elixir
{:ok, target} = JSON.decode(document)
{:ok, patch} = JSON.decode(body)

JsonMergePatch.apply_patch(target, patch)
JsonMergePatch.apply_patch(target, patch, max_depth: 32)
JsonMergePatch.apply_patch!(target, patch)
```

Authorize the change in the caller, then apply ([RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396) §5).

## Sponsor

[![Netoum](assets/netoum.png)](https://netoum.com)

## License

MIT © [Netoum](https://netoum.com). See `LICENSE`.

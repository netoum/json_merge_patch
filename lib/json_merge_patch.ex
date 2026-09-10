defmodule JsonMergePatch do
  @moduledoc """
  RFC 7396 JSON Merge Patch.

  Applies a patch to a decoded JSON value. Maps use string keys, matching
  `JSON.decode/1`. Structs and atom-key maps are rejected.

  ## Examples

      iex> JsonMergePatch.apply_patch(
      ...>   %{"a" => "b", "c" => %{"d" => "e", "f" => "g"}},
      ...>   %{"a" => "z", "c" => %{"f" => nil}}
      ...> )
      {:ok, %{"a" => "z", "c" => %{"d" => "e"}}}

  ## Behaviour

    * A non-object patch replaces the target.
    * An object patch merges into an object target. A non-object target
      becomes `%{}` first.
    * A patch value of `nil` deletes that key on the target.
    * An array patch replaces the whole value.

  See [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396).
  """

  alias JsonMergePatch.Error

  @typedoc "A decoded JSON value."
  @type json ::
          nil
          | boolean()
          | number()
          | String.t()
          | [json()]
          | %{optional(String.t()) => json()}

  @typedoc "Option for `apply_patch/3`."
  @type opt :: {:max_depth, pos_integer() | :infinity}

  @typedoc "Keyword options for `apply_patch/3`."
  @type opts :: [opt()]

  @doc """
  Applies a JSON Merge Patch to `target`.

  `target` and `patch` are decoded JSON values. Maps use string keys. Structs
  and atom-key maps are rejected.

  Returns `{:ok, json}` or `{:error, JsonMergePatch.Error.t()}`.

  ## Options

    * `:max_depth` - maximum nesting in the patch (objects and arrays). The
      top-level patch value is depth 1. Defaults to `:infinity`. Callers
      applying patches from untrusted sources should set `:max_depth`.

  ## Examples

      iex> JsonMergePatch.apply_patch(%{"a" => "b"}, %{"a" => "c"})
      {:ok, %{"a" => "c"}}

      iex> JsonMergePatch.apply_patch(%{a: 1}, %{})
      {:error, %JsonMergePatch.Error{reason: :invalid_target}}

      iex> JsonMergePatch.apply_patch(%{"a" => 1}, %{"a" => %{"b" => 2}}, max_depth: 1)
      {:error, %JsonMergePatch.Error{reason: :max_depth_exceeded}}
  """
  @spec apply_patch(term(), term()) :: {:ok, json()} | {:error, Error.t()}
  @spec apply_patch(term(), term(), opts()) :: {:ok, json()} | {:error, Error.t()}
  def apply_patch(target, patch, opts \\ []) do
    max_depth = opts |> Keyword.get(:max_depth, :infinity) |> validate_max_depth()

    with :ok <- walk(target, :invalid_target, :infinity, 1),
         :ok <- walk(patch, :invalid_patch, max_depth, 1) do
      {:ok, merge(target, patch)}
    end
  end

  @doc """
  Same as `apply_patch/3` but raises `JsonMergePatch.Error` instead of returning
  `{:error, exception}`.

  ## Examples

      iex> JsonMergePatch.apply_patch!(%{"a" => "b"}, %{"a" => "c"})
      %{"a" => "c"}
  """
  @spec apply_patch!(term(), term()) :: json()
  @spec apply_patch!(term(), term(), opts()) :: json()
  def apply_patch!(target, patch, opts \\ []) do
    case apply_patch(target, patch, opts) do
      {:ok, result} -> result
      {:error, %Error{} = error} -> raise error
    end
  end

  defp error(reason), do: {:error, %Error{reason: reason}}

  defp validate_max_depth(:infinity), do: :infinity
  defp validate_max_depth(depth) when is_integer(depth) and depth > 0, do: depth

  defp validate_max_depth(other) do
    raise ArgumentError,
          ":max_depth must be a positive integer or :infinity, got: #{inspect(other)}"
  end

  defp walk(nil, _reason, _max_depth, _depth), do: :ok

  defp walk(term, _reason, _max_depth, _depth)
       when is_boolean(term) or is_number(term) or is_binary(term) do
    :ok
  end

  defp walk(term, _reason, max_depth, depth)
       when is_integer(max_depth) and depth > max_depth and
              (is_list(term) or (is_map(term) and not is_struct(term))) do
    error(:max_depth_exceeded)
  end

  defp walk([], _reason, _max_depth, _depth), do: :ok

  defp walk([head | tail], reason, max_depth, depth) when is_list(tail) do
    with :ok <- walk(head, reason, max_depth, depth + 1) do
      walk(tail, reason, max_depth, depth)
    end
  end

  defp walk(term, reason, _max_depth, _depth) when is_list(term), do: error(reason)

  defp walk(term, reason, max_depth, depth) when is_map(term) and not is_struct(term) do
    Enum.reduce_while(term, :ok, fn
      {key, value}, :ok when is_binary(key) ->
        case walk(value, reason, max_depth, depth + 1) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      _pair, _acc ->
        {:halt, error(reason)}
    end)
  end

  defp walk(_term, reason, _max_depth, _depth), do: error(reason)

  defp merge(%{} = target, %{} = patch)
       when not is_struct(target) and not is_struct(patch) do
    Enum.reduce(patch, target, fn
      {key, nil}, acc -> Map.delete(acc, key)
      {key, value}, acc -> Map.put(acc, key, merge(Map.get(acc, key), value))
    end)
  end

  defp merge(_target, %{} = patch) when not is_struct(patch), do: merge(%{}, patch)

  defp merge(_target, patch), do: patch
end

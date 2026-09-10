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

  @typedoc "Reason stored on `JsonMergePatch.Error`."
  @type error_reason :: Error.reason()

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
      top-level patch value is depth 1. Defaults to `:infinity`.

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
    max_depth = Keyword.get(opts, :max_depth, :infinity)

    with :ok <- validate(target, :invalid_target),
         :ok <- validate_patch(patch, max_depth, 1) do
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
      {:error, %Error{reason: reason}} -> raise Error, reason: reason
    end
  end

  defp validate(term, reason) do
    if json_term?(term) do
      :ok
    else
      {:error, %Error{reason: reason}}
    end
  end

  defp validate_patch(term, :infinity, _depth) do
    validate(term, :invalid_patch)
  end

  defp validate_patch(term, max_depth, depth) when is_integer(max_depth) do
    cond do
      json_scalar?(term) ->
        :ok

      json_container?(term) and depth > max_depth ->
        {:error, %Error{reason: :max_depth_exceeded}}

      is_map(term) and not is_struct(term) ->
        validate_map_values(term, max_depth, depth)

      is_list(term) ->
        validate_list_elements(term, max_depth, depth)

      true ->
        {:error, %Error{reason: :invalid_patch}}
    end
  end

  defp json_scalar?(nil), do: true
  defp json_scalar?(term) when is_boolean(term) or is_number(term) or is_binary(term), do: true
  defp json_scalar?(_term), do: false

  defp json_container?(term) when is_list(term), do: true
  defp json_container?(%{} = term) when not is_struct(term), do: true
  defp json_container?(_term), do: false

  defp validate_map_values(map, max_depth, depth) do
    Enum.reduce_while(map, :ok, fn
      {key, value}, :ok when is_binary(key) ->
        case validate_patch(value, max_depth, depth + 1) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      _pair, _acc ->
        {:halt, {:error, %Error{reason: :invalid_patch}}}
    end)
  end

  defp validate_list_elements([], _max_depth, _depth), do: :ok

  defp validate_list_elements([head | tail], max_depth, depth) when is_list(tail) do
    with :ok <- validate_patch(head, max_depth, depth + 1) do
      validate_list_elements(tail, max_depth, depth)
    end
  end

  defp validate_list_elements(_term, _max_depth, _depth) do
    {:error, %Error{reason: :invalid_patch}}
  end

  defp merge(target, %{} = patch) when not is_struct(patch) do
    base = if json_object?(target), do: target, else: %{}

    Enum.reduce(patch, base, fn
      {key, nil}, acc -> Map.delete(acc, key)
      {key, value}, acc -> Map.put(acc, key, merge(Map.get(acc, key), value))
    end)
  end

  defp merge(_target, patch), do: patch

  defp json_object?(%{} = term) when not is_struct(term), do: true
  defp json_object?(_term), do: false

  defp json_term?(nil), do: true

  defp json_term?(term) when is_boolean(term) or is_number(term) or is_binary(term) do
    true
  end

  defp json_term?([]), do: true

  defp json_term?([head | tail]) when is_list(tail) do
    json_term?(head) and json_term?(tail)
  end

  defp json_term?(term) when is_map(term) and not is_struct(term) do
    Enum.all?(term, fn
      {key, value} when is_binary(key) -> json_term?(value)
      _ -> false
    end)
  end

  defp json_term?(_term), do: false
end

defmodule JsonMergePatch.Error do
  @moduledoc """
  Exception returned or raised by `JsonMergePatch`.

  `JsonMergePatch.apply_patch/2` returns `{:error, exception}` and
  `JsonMergePatch.apply_patch!/2` raises. A call reports one error: the target
  is checked first, then the patch. If both are invalid, `reason` is
  `:invalid_target`.

    * `:invalid_target` - the target is not a JSON value
    * `:invalid_patch` - the patch is not a JSON value
    * `:max_depth_exceeded` - the patch nesting is over `:max_depth`
  """

  @type reason :: :invalid_target | :invalid_patch | :max_depth_exceeded
  @type t :: %__MODULE__{reason: reason()}

  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: :invalid_target}) do
    "invalid JSON Merge Patch target"
  end

  def message(%__MODULE__{reason: :invalid_patch}) do
    "invalid JSON Merge Patch patch"
  end

  def message(%__MODULE__{reason: :max_depth_exceeded}) do
    "JSON Merge Patch exceeds max depth"
  end
end

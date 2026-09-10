defmodule JsonMergePatchTest do
  use ExUnit.Case, async: true
  doctest JsonMergePatch

  describe "empty object patch" do
    test "leaves an object target unchanged" do
      assert JsonMergePatch.apply_patch(%{"a" => 1}, %{}) == {:ok, %{"a" => 1}}
    end

    test "replaces a non-object target with an empty object" do
      assert JsonMergePatch.apply_patch("foo", %{}) == {:ok, %{}}
      assert JsonMergePatch.apply_patch(nil, %{}) == {:ok, %{}}
      assert JsonMergePatch.apply_patch([1], %{}) == {:ok, %{}}
    end
  end

  describe "null at root" do
    test "replaces any target with nil" do
      assert JsonMergePatch.apply_patch(%{"a" => 1}, nil) == {:ok, nil}
      assert JsonMergePatch.apply_patch([1, 2, 3], nil) == {:ok, nil}
      assert JsonMergePatch.apply_patch(true, nil) == {:ok, nil}
    end
  end

  describe "array replace" do
    test "does not merge array elements" do
      assert JsonMergePatch.apply_patch([1, 2, 3], [4]) == {:ok, [4]}
      assert JsonMergePatch.apply_patch(%{"a" => [1, 2]}, %{"a" => [3]}) == {:ok, %{"a" => [3]}}
    end
  end

  describe "nested null delete" do
    test "deletes a nested key and keeps siblings" do
      target = %{"a" => %{"x" => 1, "y" => 2}, "b" => 3}
      patch = %{"a" => %{"x" => nil}}
      assert JsonMergePatch.apply_patch(target, patch) == {:ok, %{"a" => %{"y" => 2}, "b" => 3}}
    end

    test "deleting a missing nested key is a no-op on that object" do
      assert JsonMergePatch.apply_patch(%{"a" => %{"y" => 2}}, %{"a" => %{"x" => nil}}) ==
               {:ok, %{"a" => %{"y" => 2}}}
    end
  end

  describe "boolean, number, and string patches" do
    test "boolean, number, and string patches replace the target" do
      assert JsonMergePatch.apply_patch(%{"a" => 1}, true) == {:ok, true}
      assert JsonMergePatch.apply_patch(%{"a" => 1}, false) == {:ok, false}
      assert JsonMergePatch.apply_patch(%{"a" => 1}, 42) == {:ok, 42}
      assert JsonMergePatch.apply_patch(%{"a" => 1}, 1.5) == {:ok, 1.5}
      assert JsonMergePatch.apply_patch(%{"a" => 1}, "foo") == {:ok, "foo"}
    end
  end

  describe "invalid terms" do
    test "rejects atom-key maps as the target" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch(%{a: 1}, %{})
    end

    test "rejects atom-key maps as the patch" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, %{a: 1})
    end

    test "rejects nested atom-key maps" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch(%{"a" => %{b: 1}}, %{})

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, %{"a" => %{b: 1}})
    end

    test "rejects structs as the target" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch(%URI{}, %{})
    end

    test "rejects structs as the patch" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, DateTime.utc_now())
    end

    test "rejects atoms other than booleans and nil" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch(:foo, %{})

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, :foo)
    end

    test "rejects tuples" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch({1, 2}, %{})

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, {1, 2})
    end

    test "rejects improper lists without raising" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch([1 | 2], %{})

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, [1 | 2])
    end

    test "rejects nested invalid values in lists" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch([1, {2, 3}], %{})

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, [1, {2, 3}])

      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch([%{"a" => 1}, %{b: 1}], %{})

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, [%{a: 1}])
    end

    test "reports invalid_target when both sides are invalid" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_target}} =
               JsonMergePatch.apply_patch(%{a: 1}, %{b: 2})
    end
  end

  describe "apply_patch!/2" do
    test "returns the merged term" do
      assert JsonMergePatch.apply_patch!(%{"a" => "b"}, %{"a" => "c"}) == %{"a" => "c"}
    end

    test "raises on an invalid target" do
      error =
        assert_raise JsonMergePatch.Error, "invalid JSON Merge Patch target", fn ->
          JsonMergePatch.apply_patch!(%{a: 1}, %{})
        end

      assert error.reason == :invalid_target
    end

    test "raises on an invalid patch" do
      error =
        assert_raise JsonMergePatch.Error, "invalid merge patch", fn ->
          JsonMergePatch.apply_patch!(%{}, %{a: 1})
        end

      assert error.reason == :invalid_patch
    end

    test "raise without a reason does not crash in message/1" do
      error =
        assert_raise JsonMergePatch.Error, "JSON Merge Patch error", fn ->
          raise JsonMergePatch.Error
        end

      assert error.reason == nil
    end
  end

  describe "max_depth" do
    test "applies a patch within the limit" do
      assert JsonMergePatch.apply_patch(%{"a" => 1}, %{"a" => 2}, max_depth: 1) ==
               {:ok, %{"a" => 2}}

      assert JsonMergePatch.apply_patch(%{"a" => 1}, %{"a" => %{"b" => 2}}, max_depth: 2) ==
               {:ok, %{"a" => %{"b" => 2}}}
    end

    test "rejects a patch one level too deep without raising" do
      assert {:error, %JsonMergePatch.Error{reason: :max_depth_exceeded}} =
               JsonMergePatch.apply_patch(%{"a" => 1}, %{"a" => %{"b" => 2}}, max_depth: 1)

      assert {:error, %JsonMergePatch.Error{reason: :max_depth_exceeded}} =
               JsonMergePatch.apply_patch(%{}, %{"a" => [1]}, max_depth: 1)
    end

    test "default infinity leaves nested patches working" do
      patch = %{"a" => %{"b" => %{"c" => 1}}}

      assert JsonMergePatch.apply_patch(%{}, patch) == {:ok, patch}
      assert JsonMergePatch.apply_patch(%{}, patch, max_depth: :infinity) == {:ok, patch}
    end

    test "apply_patch!/3 raises with max_depth_exceeded" do
      error =
        assert_raise JsonMergePatch.Error, "JSON Merge Patch exceeds max depth", fn ->
          JsonMergePatch.apply_patch!(%{"a" => 1}, %{"a" => %{"b" => 2}}, max_depth: 1)
        end

      assert error.reason == :max_depth_exceeded
    end

    test "still rejects invalid patch terms when max_depth is set" do
      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, %{a: 1}, max_depth: 8)

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, [1 | 2], max_depth: 8)

      assert {:error, %JsonMergePatch.Error{reason: :invalid_patch}} =
               JsonMergePatch.apply_patch(%{}, {1, 2}, max_depth: 8)
    end

    test "walks lists and nil within the limit" do
      assert JsonMergePatch.apply_patch(%{"a" => 1}, nil, max_depth: 1) == {:ok, nil}
      assert JsonMergePatch.apply_patch([1], [], max_depth: 1) == {:ok, []}
      assert JsonMergePatch.apply_patch(%{"a" => 1}, [1, 2], max_depth: 2) == {:ok, [1, 2]}
    end

    test "limits patch nesting only, not the target" do
      target = %{"a" => %{"b" => %{"c" => 1}}}

      assert JsonMergePatch.apply_patch(target, %{"a" => 2}, max_depth: 1) ==
               {:ok, %{"a" => 2}}
    end

    test "raises ArgumentError for an invalid max_depth" do
      message = ":max_depth must be a positive integer or :infinity"

      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        JsonMergePatch.apply_patch(%{}, %{}, max_depth: 0)
      end

      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        JsonMergePatch.apply_patch(%{}, %{}, max_depth: -1)
      end

      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        JsonMergePatch.apply_patch(%{}, %{}, max_depth: "foo")
      end

      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        JsonMergePatch.apply_patch(%{}, %{}, max_depth: nil)
      end
    end
  end
end

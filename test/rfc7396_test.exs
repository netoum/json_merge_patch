defmodule JsonMergePatch.RFC7396Test do
  use ExUnit.Case, async: true

  # Appendix A of RFC 7396: https://datatracker.ietf.org/doc/html/rfc7396#appendix-A
  @appendix_a [
    {"replaces a member value", %{"a" => "b"}, %{"a" => "c"}, %{"a" => "c"}},
    {"adds a member", %{"a" => "b"}, %{"b" => "c"}, %{"a" => "b", "b" => "c"}},
    {"deletes a member with null", %{"a" => "b"}, %{"a" => nil}, %{}},
    {"deletes a member and leaves the rest", %{"a" => "b", "b" => "c"}, %{"a" => nil},
     %{"b" => "c"}},
    {"replaces an array with a scalar", %{"a" => ["b"]}, %{"a" => "c"}, %{"a" => "c"}},
    {"replaces a scalar with an array", %{"a" => "c"}, %{"a" => ["b"]}, %{"a" => ["b"]}},
    {"recursively merges and deletes nested members", %{"a" => %{"b" => "c"}},
     %{"a" => %{"b" => "d", "c" => nil}}, %{"a" => %{"b" => "d"}}},
    {"replaces an array of objects with a different array", %{"a" => [%{"b" => "c"}]},
     %{"a" => [1]}, %{"a" => [1]}},
    {"replaces an array with another array", ["a", "b"], ["c", "d"], ["c", "d"]},
    {"replaces an object with an array", %{"a" => "b"}, ["c"], ["c"]},
    {"replaces an object with null at the root", %{"a" => "foo"}, nil, nil},
    {"replaces an object with a string at the root", %{"a" => "foo"}, "bar", "bar"},
    {"adds a member while preserving an existing null", %{"e" => nil}, %{"a" => 1},
     %{"e" => nil, "a" => 1}},
    {"replaces a non-object target with an object, ignoring null keys", [1, 2],
     %{"a" => "b", "c" => nil}, %{"a" => "b"}},
    {"nested null deletes a missing key and leaves an empty object", %{},
     %{"a" => %{"bb" => %{"ccc" => nil}}}, %{"a" => %{"bb" => %{}}}}
  ]

  for {name, target, patch, expected} <- @appendix_a do
    test "Appendix A: #{name}" do
      assert JsonMergePatch.apply_patch(
               unquote(Macro.escape(target)),
               unquote(Macro.escape(patch))
             ) == {:ok, unquote(Macro.escape(expected))}
    end
  end

  # https://datatracker.ietf.org/doc/html/rfc7396#section-3
  test "Section 3: recursive merge, nested delete, and array replace" do
    target = %{
      "title" => "Goodbye!",
      "author" => %{
        "givenName" => "John",
        "familyName" => "Doe"
      },
      "tags" => ["example", "sample"],
      "content" => "This will be unchanged"
    }

    patch = %{
      "title" => "Hello!",
      "phoneNumber" => "+01-123-456-7890",
      "author" => %{
        "familyName" => nil
      },
      "tags" => ["example"]
    }

    expected = %{
      "title" => "Hello!",
      "author" => %{
        "givenName" => "John"
      },
      "tags" => ["example"],
      "content" => "This will be unchanged",
      "phoneNumber" => "+01-123-456-7890"
    }

    assert JsonMergePatch.apply_patch(target, patch) == {:ok, expected}
  end
end

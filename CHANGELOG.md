# Changelog

## v0.1.0 (2026-09-11)

Initial release. RFC 7396 JSON Merge Patch on decoded JSON values.

  * [JsonMergePatch] Add `apply_patch/2` and `apply_patch!/2`
  * [JsonMergePatch] Add `:max_depth` to limit patch nesting
  * [JsonMergePatch.Error] Add `:invalid_target`, `:invalid_patch`, and `:max_depth_exceeded`

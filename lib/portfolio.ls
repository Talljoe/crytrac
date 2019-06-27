require! <[ ./locale js-yaml ]>
require! 'fs' : { readFileSync, existsSync}
require! 'prelude-ls' : { lines, map, split, filter, group-by, obj-to-pairs, sum, Obj, values, flatten }
obj-map = Obj.map

export
  ensure-exists: (file) ->
    unless existsSync file
      console.error "Cannot find file #{file}."
      process.exit -1

  load: (file) ->
    readFileSync file, \utf8
    |> lines
    |> map split "#" |> map (.0) # remove comments
    |> map split ":"
    |> map map (.trim!)
    |> filter (.1?)
    |> group-by (.0)
    |> obj-map -> it |> map (.1) |> map locale.get-parser! |> sum
    |> obj-to-pairs
    |> map ->
      symbol: it.0
      amount: it.1

  load-new: (file) ->
    readFileSync file, \utf8
    |> jsYaml.safeLoad
    |> values
    |> filter (.assets?)
    |> map (.assets)
    |> flatten
    |> group-by (.id)
    |> obj-map -> it |> map (.count) |> sum
    |> obj-to-pairs
    |> map ->
      id: it.0
      amount: it.1


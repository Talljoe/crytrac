require! <[ rest timespan ]>
require! 'prelude-ls' : { map, filter, lines, sum, each }

data-url = "https://api.coinmarketcap.com/v1/"
client = rest.wrap require('rest/interceptor/mime')
             .wrap require('rest/interceptor/errorCode')
             .wrap require('rest/interceptor/retry', ), initial: timespan.from-seconds(5).total-milliseconds!
             .wrap require('rest/interceptor/timeout'), timeout: timespan.from-seconds(80).total-milliseconds!
             .wrap require('rest/interceptor/pathPrefix'), prefix: data-url
require! bluebird: Promise
require! <[ ./lib/portfolio ./lib/cli-options ]>

options = cli-options.get-options!

portfolio.ensure-exists options.file
renderer = new options.Renderer(options)

execute = (cb = console.log) ->
  portfolio.load(options.file)
  |> get-latest
  |> (.then renderer.render)
  |> (.then cb)

if options.watch
  display = require(\charm)(process)
    .cursor false

  process.on \exit ->
    display.cursor true
    console.log!
  last-rows = 0

  display-latest-values = ->
    display.up(last-rows - 1).left(999).cursor(true) if last-rows
    execute ->
      display.erase(\down).write(it).cursor(false)
      last-rows := it |> lines |> (.length)
    |> (.catch !->)
  display-latest-values!

  interval = timespan.from-seconds(90).total-milliseconds!
  setInterval display-latest-values, interval
else
  execute!.catch (e) !->
    throw e
    process.exit -1

function get-latest(hodlings)
  process-data = (global, currencies) ->
    get-value = ({ symbol, amount }) ->
      currency = currencies[symbol]
      unless currency? then
        console.error "Unknown coin: #{symbol}"
        return

      fx = options.convert.toLowerCase!
      price = currency["price_#{fx}"] |> parseFloat
      price-btc = currency.price_btc |> parseFloat
      amount-for-currency = (*) amount
      value = amount-for-currency price
      value-btc = amount-for-currency price-btc
      return
        count: amount
        value: value
        value-btc: value-btc
        price: price
        price-btc: price-btc
        symbol: symbol
        amount: amount
        market-cap: currency["market_cap_#{fx}"] |> parseFloat
        currency: currency

    details =
      hodlings
      |> map get-value
      |> filter (?)

    grand-total = details |> map (.value) |> sum
    details |> each -> it.percentage = it.value / grand-total

    return
      grand-total: grand-total
      details: details
      global: global

  convert-string =
    | options.convert is /^USD$/i => ""
    | otherwise => "?convert=#{options.convert}"

  make-request = (url) ->
    url + convert-string
    |> client
    |> (.entity!)

  Promise.join do
    make-request(\global/)
    make-request(\ticker/?limit=0).then (entity) -> { [..symbol, ..] for entity }
    process-data
  .catch (e) !->
    console.error "!!! Error accessing service: #{e}"
    throw e
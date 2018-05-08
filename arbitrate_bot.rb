require 'rubygems'
require 'telegram/bot'
require 'binance-ruby'
require_relative 'vip_trade'

class ArbitrateBot
  def my_asset(kurs)
    binance_assets = Binance::Api.info!
    bn_usdt = binance_assets[:balances].find {|x| x[:asset] == "USDT"}[:free].to_f
    bn_usdt_idr = bn_usdt * kurs

    vip_btc = VipTrade.new
    vip_assets = vip_btc.info
    vip_idr = vip_assets['balance']['idr']

    asset = bn_usdt_idr + vip_idr
    asset
  end

  def trade!(lot, kurs, spread)
    text = ""

    Binance::Api::Configuration.api_key = 'BINANCE API KEY'
    Binance::Api::Configuration.secret_key = 'BINANCE SECRET KEY'

    start_count = 0
    counter = 0

    # QTY will be set on Telegram in the future
    qty = lot
    kurs = kurs

    until counter == 2 do
      counter = counter + 1

      text += "<b>Try #{counter}</b>\n\n"

      initial_asset = my_asset(kurs)
      text += "<b>Initial Asset</b>: #{initial_asset.to_i}\n\n"

      vip_btc = VipTrade.new
      vip_ticker = vip_btc.ticker

      vip_high = vip_ticker["high"]
      vip_low = vip_ticker["low"]
      vip_buy = vip_ticker["buy"].to_f
      vip_sell = vip_ticker["sell"].to_f

      text += "<b>VIP BTC</b>\n"
      text += "buy: #{vip_buy}\n"
      text += "sell: #{vip_sell}\n"

      # binance = Binance.new
      bn_ticker = Binance::Api.ticker!(symbol: 'BTCUSDT', type: 'daily')

      bn_high = bn_ticker[:highPrice]
      bn_low = bn_ticker[:lowPrice]
      bn_buy = bn_ticker[:askPrice].to_f
      bn_sell = bn_ticker[:bidPrice].to_f

      text += "<b>BINANCE BTC</b>\n"
      text += "buy: #{bn_buy}\n"
      text += "sell: #{bn_sell}\n\n"

      vip_buyUsd = (vip_buy / kurs)
      vip_sellUsd = (vip_sell / kurs)

      puts "VIP #{vip_buyUsd}"

      bnbuy_vipsell = (((bn_sell - vip_buyUsd) / bn_sell) * 100).round(3)
      vipbuy_bnsell = (((vip_sellUsd - bn_buy) /vip_sellUsd) * 100).round(3)

      text += "<b>SPREAD BUY BINANCE -> VIP SELL</b>\n"
      text += "#{bnbuy_vipsell}\n\n"

      text += "<b>SPREAD BUY VIP -> BINANCE SELL</b>\n"
      text += "#{vipbuy_bnsell}\n\n"

      if bnbuy_vipsell >= spread
        # Sell in VIP
        # vip_btc.sell(qty)

        # Buy 15$ BTC
        # Binance::Api::Order.create!(symbol: 'BTCUSDT', side: 'BUY', type: 'LIMIT', price: bn_sell, quantity: qty, timeInForce: 'GTC')

        current_asset = my_asset(kurs).to_i
        text += "<b>Current Asset: #{current_asset}</b>\n"
        text += "<b>Profit: #{current_asset - initial_asset}</b>\n\n"
      elsif vipbuy_bnsell >= spread
        # Sell in VIP
        # vip_btc.buy(qty)

        # Buy 15$ BTC
        # Binance::Api::Order.create!(symbol: 'BTCUSDT', side: 'SELL', type: 'LIMIT', price: bn_sell, quantity: qty, timeInForce: 'GTC')

        current_asset = my_asset(kurs).to_i
        text += "<b>Current Asset: #{current_asset}</b>\n"
        text += "<b>Profit: #{current_asset - initial_asset}</b>\n\n"
      end

      sleep 5
    end

    puts "Finish Trade"
    return text
  end
end

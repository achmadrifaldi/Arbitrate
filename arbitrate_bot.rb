require 'dotenv/load'
require 'rubygems'
require 'binance-ruby'
require_relative 'vip_trade'

class ArbitrateBot
  def my_asset(kurs)
    bn_ticker = Binance::Api.ticker!(symbol: 'BTCUSDT', type: 'daily')
    bn_buy = bn_ticker[:askPrice].to_f

    btcpr = bn_ticker[:askPrice].to_f * kurs

    binance_assets = Binance::Api.info!
    bn_usdt = binance_assets[:balances].find {|x| x[:asset] == "USDT"}[:free].to_f
    bn_btc   =  binance_assets[:balances].find {|x| x[:asset] == "BTC"}[:free].to_f
    bn_usdt_idr = bn_usdt * kurs
    bn_btc_idr = bn_btc * btcpr.to_f



    vip_btc = VipTrade.new
    vip_ticker = vip_btc.ticker
    vip_buy = vip_ticker["buy"].to_f
    vip_assets = vip_btc.info
    vip_idr = vip_assets['balance']['idr'].to_f
    vip_btc_blc = vip_assets['balance']['btc'].to_f
    vip_btc_idr = vip_btc_blc * btcpr.to_f

    asset = bn_usdt_idr + bn_btc_idr + vip_idr + vip_btc_idr

    asset
  end

  def trade!(lot, kurs, spread)
    text = ""

    Binance::Api::Configuration.api_key = ENV['BINANCE_API_KEY']
    Binance::Api::Configuration.secret_key = ENV['BINANCE_SECRET_KEY']

    start_count = 0
    counter = 0

    # QTY will be set on Telegram in the future
    qty = lot
    kurs = kurs
    profit = 0

    until counter == 2 do
      counter = counter + 1

      bn_ticker = Binance::Api.ticker!(symbol: 'BTCUSDT', type: 'daily')
      bn_buy = bn_ticker[:askPrice].to_f

      btcpr = bn_ticker[:askPrice].to_f * kurs

      binance_assets = Binance::Api.info!
      bn_usdt = binance_assets[:balances].find {|x| x[:asset] == "USDT"}[:free].to_f
      bn_btc   =  binance_assets[:balances].find {|x| x[:asset] == "BTC"}[:free].to_f
      bn_usdt_idr = bn_usdt * kurs
      bn_btc_idr = bn_btc * btcpr.to_f

      vip_btc = VipTrade.new
      vip_ticker = vip_btc.ticker
      vip_buy = vip_ticker["buy"].to_f
      vip_assets = vip_btc.info
      vip_idr = vip_assets['balance']['idr'].to_f
      vip_btc_blc = vip_assets['balance']['btc'].to_f
      vip_btc_idr = vip_btc_blc * btcpr.to_f


      text += "<b>Try #{counter}</b>\n\n"

      initial_asset = my_asset(kurs)

      text += "<b>Initial Asset</b>:Bn  Idr #{bn_usdt_idr.to_i}\n"
      text += "<b>Initial Asset</b>:Bn  Btc #{bn_btc.round(4)}\t\t#{bn_btc_idr.to_i}\n"
      text += "<b>Initial Asset</b>:Vip Idr #{vip_idr.to_i}\n"
      text += "<b>Initial Asset</b>:Bn Btc #{vip_btc_blc.round(4)}\t\t#{vip_btc_idr.to_i}\n"
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
      bn_buy = bn_ticker[:bidPrice].to_f
      bn_sell = bn_ticker[:askPrice].to_f

      text += "<b>BINANCE BTC</b>\n"
      text += "buy: #{bn_buy}\n"
      text += "sell: #{bn_sell}\n\n"

      vip_buyUsd = (vip_buy / kurs).to_f
      vip_sellUsd = (vip_sell / kurs).to_f

      puts "VIP Buy #{vip_buyUsd}"
      puts "VIP SELL #{vip_sellUsd}"


      bnbuy_vipsell = (((vip_buyUsd / bn_sell) - 1) * 100).round(3)

      vipbuy_bnsell = (((bn_buy / vip_sellUsd) - 1) * 100).round(3)


      text += "<b>SPREAD BUY BINANCE -> VIP SELL</b>\n"
      text += "#{bnbuy_vipsell}\n\n"

      text += "<b>SPREAD BUY VIP -> BINANCE SELL</b>\n"
      text += "#{vipbuy_bnsell}\n\n"

      if bnbuy_vipsell >= spread
        # Sell in VIP
        vip_btc.sell(qty)

        # Buy 15$ BTC
        Binance::Api::Order.create!(symbol: 'BTCUSDT', side: 'BUY', type: 'LIMIT', price: bn_sell, quantity: qty, timeInForce: 'GTC')

        current_asset = my_asset(kurs).to_f
        text += "<b>Current Asset: #{current_asset}</b>\n"
        text += "<b>Profit: #{current_asset - initial_asset}</b>\n\n"

      elsif vipbuy_bnsell >= spread
        # Sell in VIP
        vip_btc.buy(qty)

        # Buy 15$ BTC
        Binance::Api::Order.create!(symbol: 'BTCUSDT', side: 'SELL', type: 'LIMIT', price: bn_sell, quantity: qty, timeInForce: 'GTC')

        current_asset = my_asset(kurs).to_f
        text += "<b>Current Asset: #{current_asset}</b>\n"
      end

      sleep 5
    end

    puts "Finish Trade"
    return text
  end

  def balance
    text = ""

    begin
      binance_assets = Binance::Api.info!(recvWindow: 10000)
      bn_usdt = binance_assets[:balances].find {|x| x[:asset] == "USDT"}[:free].to_f
      bn_btc = binance_assets[:balances].find {|x| x[:asset] == "BTC"}[:free].to_f
      text += "<b>BINANCE BALANCE</b>\n"
      text += "USDT: #{bn_usdt}\n"
      text += "BTC: #{bn_btc}\n"

    rescue => e
      text += "<b>Failed to get BINANCE Info</b>\n"
      text += e.inspect.to_s
      text += "\n\n"
    end

    begin
      vip_btc = VipTrade.new
      vip_assets = vip_btc.info
      vip_idr = vip_assets['balance']['idr']
      vip_btc = vip_assets['balance']['btc']
      text += "<b>VIP BALANCE</b>\n"
      text += "IDR: #{vip_idr}\n"
      text += "BTC: #{vip_btc}\n"
    rescue => e
      text += "<b>Failed to get VIP Info</b>\n"
      text += e.inspect.to_s
      text += "\n\n"
    end

    return text
  end
end

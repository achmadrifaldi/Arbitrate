require 'binance-ruby'

class BinanceBot
  Binance::Api::Configuration.api_key = 'BINANCE API KEY'
  Binance::Api::Configuration.secret_key = 'BINANCE SECRET KEY'

  def info(symbol='BTCUSDT')
    bn_account = Binance::Api.info!
    bn_ticker = Binance::Api.ticker!(symbol: symbol, type: 'daily')

    bn_high = bn_ticker[:highPrice].to_f
    bn_low = bn_ticker[:lowPrice].to_f
    bn_buy = bn_ticker[:askPrice].to_f
    bn_sell = bn_ticker[:bidPrice].to_f

    text_info = "BINANCE INFO\n\n"
    bn_account[:balances].map{|balance|
      text_info += "#{balance[:asset]} Balance: #{balance[:free]}\n"
    }

    text_info += "\n\nBINANCE MARKET INFO\n\n"
    text_info += "High Price: $#{bn_high}\n"
    text_info += "Low Price: $#{bn_low}\n"
    text_info += "Ask Price: $#{bn_buy}\n"
    text_info += "Bid Price: $#{bn_sell}\n"

    text_info
  end
end

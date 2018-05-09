require 'dotenv/load'
require 'rest-client'
require 'colorize'
require 'json'
require 'cgi'
require 'open-uri'

class VipTrade
  BASE_URL = 'https://vip.bitcoin.co.id'
  MARKET_NAME = 'btc_idr'
  CURRENCY = 'btc'
  KURS = 13900
  API_KEY = ENV['VIP_API_KEY']
  API_SECRET = ENV['VIP_SECET_KEY']
  URIs = {
    public: {
      ticker: '/api/btc_idr/ticker/',
      order_book: "/api/btc_idr/depth/",
      last_trades: "/api/btc_idr/trades/",
    },
    account: {
      balance: "/tapi?method=getInfo",
    },
    market: {
      buy: "/tapi?method=trade&pair=%s&type=buy&price=%s&idr=%s",
      sell: "/tapi?method=trade&pair=%s&type=sell&price=%s&btc=%s",
      cancel_by_uuid: "/tapi?order_id=%s&method=CancelOrder",
      open_orders: "/tapi?pair=%s&method=ActiveOrders"
    }
  }

  def call_secret_api(url)
    params = (url.split("?").size == 2) ? url.split("?")[1] : ""
    sign = hmac_sha256(params, API_SECRET)
    api_endpoint = url.split("?")[0]
    payload = url.split("?")[1]
    params = {}

    payload.split("&").each do |arg|
      k, v = arg.split("=")
      params[k.to_s] = v.to_s
    end

    response = RestClient.post(api_endpoint, params, {
      Key: API_KEY,
      Sign: sign,
      'User-Agent'=> "Mozilla/5.0",
      "Content-Type" => "application/x-www-form-urlencoded"
    })

    puts "Calling API...".yellow
    parsed_body = JSON.parse(response.body)
    p [url, parsed_body]
    puts (parsed_body["success"] ? "Success".green : "Failed".red)
    parsed_body["return"] if parsed_body["success"]
  end

  def hmac_sha256(msg, key)
    p URI::encode(msg)
    digest = OpenSSL::Digest.new("sha512")
    OpenSSL::HMAC.hexdigest(digest, key, URI::encode(msg))
  end

  def get_url(params)
    url = VipTrade::BASE_URL + VipTrade::URIs[params[:api_type].to_sym][params[:action].to_sym]
    case params[:action]
      when "buy"
        url = sprintf(url, params[:market], params[:rate], params[:quantity])
      when "sell"
        url = sprintf(url, params[:market], params[:rate], params[:quantity])
      when "cancel_by_uuid"
        url = sprintf(url, params[:order_id])
      when "open_orders", "ticker", "last_trades"
        url = sprintf(url, params[:market])
      when "order_book"
        url = sprintf(url, params[:market])
    end
    # nonce = (Time.now.to_i + 10).to_s
    epoch_mirco = Time.now.to_f
    epoch_full = Time.now.to_i
    epoch_fraction = epoch_mirco - epoch_full

    nonce = epoch_fraction + epoch_full
    url = url + "&nonce=#{nonce}" if ["market","account"].include? params[:api_type]
    return url
  end

  def ticker
    url = get_url(
      {
        api_type: "public",
        action: "ticker",
        market: VipTrade::MARKET_NAME
      }
    )

    response = RestClient.get(url)
    parsed_body = JSON.parse(response.body)
    puts (parsed_body["ticker"] ? "Ticker Success".green : "Ticker Failed".red)
    parsed_body["ticker"] if parsed_body["ticker"]
  end

  def info
    get_balance_url = get_url({
      api_type: "account",
      action: "balance"
    })
    balance_details = call_secret_api(get_balance_url)
  end

  def get_market_summary(market_name)
    market_summary_url = get_url(
      {
        api_type: "public",
        action: "ticker",
        market: market_name
      }
    )
    summary = self.ticker
    low_24_hr, last_price, ask_price, volume = summary["low"].to_i, summary["last"].to_i, summary["sell"].to_i, summary["vol_btc"].to_f
    [low_24_hr, last_price, ask_price, volume]
  end

  def sell(qty)
    market_name = VipTrade::MARKET_NAME
    currency = VipTrade::CURRENCY
    low_24_hr, last_price, ask_price = get_market_summary(market_name)

    sell_price = last_price
    sell_price = "%.8f" % sell_price

    get_balance_url = get_url({
      api_type: "account",
      action: "balance"
    })
    balance_details = call_secret_api(get_balance_url)

    if balance_details && balance_details['balance'] && balance_details['balance'][currency] && balance_details['balance'][currency].to_f > 0.0
      p [market_name, last_price, balance_details['balance'][currency], sell_price]

      sell_limit_url = get_url({
        api_type: "market",
        action: "sell",
        market: market_name,
        quantity: qty,
        rate: sell_price
      })

      puts "Selling coin...".yellow
      p [{
        api_type: "market",
        action: "sell",
        market: market_name,
        quantity: qty,
        rate: sell_price
      }]
      order_placed = call_secret_api(sell_limit_url)
      puts (order_placed && !order_placed["order_id"].nil? ? "Success".green : "Failed".red)

      count = 1
      while count <= 3 && order_placed && order_placed["order_id"].nil? #retry
        puts "Retry #{count} : Selling coin...".yellow
        sleep(1) # half second
        order_placed = call_secret_api(sell_limit_url)
        puts (order_placed && !order_placed["order_id"].nil? ? "Success".green : "Failed".red)
        count += 1
      end
      p [order_placed, "Sell #{balance_details['balance'][currency]} of #{market_name} at #{sell_price}"]
    else
      puts "Insufficient Balance".red
    end
  end

  def buy(qty)
    market_name = VipTrade::MARKET_NAME
    low_24_hr, last_price, ask_price, volume = get_market_summary(market_name)
    quantity = qty * last_price

    buy_limit_url = get_url({ api_type: "market", action: "buy", market: market_name, quantity: quantity, rate: last_price })

    puts "Purchasing coin...".yellow
    p [{ api_type: "market", action: "buy", market: market_name, quantity: quantity, rate: last_price }]

    order = call_secret_api(buy_limit_url)
    puts ((order && !order["order_id"].nil?) ? "Success".green : "Failed".red)

    cnt = 1
    while cnt <= 3 && order && order["order_id"].nil? #retry
      puts "Retry #{cnt}: Purchasing coin...".yellow
      sleep(1) # half second
      order = call_secret_api(buy_limit_url)
      puts ((order && !order["order_id"].nil?) ? "Success".green : "Failed".red)
      cnt += 1
    end
    @units_bought = quantity if order && !order["order_id"].nil?
    order
  end
end

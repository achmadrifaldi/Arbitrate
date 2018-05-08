require 'rest-client'
require 'colorize'
require 'json'
require 'cgi'
require 'open-uri'

class VipBot
  BASE_URL = 'https://vip.bitcoin.co.id'
  MARKET_NAME = 'btc_idr'
  CURRENCY = 'btc'
  API_KEY = 'YOUR VIP API KEY'
  API_SECRET = 'YOUR VIP SECRET KEY'
  URIs = {
      public: {
        ticker: '/api/btc_idr/ticker/'
      },
      account: {
        balance: "/tapi?method=getInfo",
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
    url = VipBot::BASE_URL + VipBot::URIs[params[:api_type].to_sym][params[:action].to_sym]

    case params[:action]
      when "ticker"
        url = sprintf(url, params[:market])
    end

    nonce = Time.now.to_i.to_s
    url = url + "&nonce=#{nonce}" if ["account"].include? params[:api_type]
    return url
  end

  def ticker
    url = get_url({
      api_type: "public",
      action: "ticker",
      market: VipBot::MARKET_NAME
    })

    response = RestClient.get(url)
    parsed_body = JSON.parse(response.body)
    parsed_body["ticker"] if parsed_body["ticker"]
  end

  def account
    get_balance_url = get_url({
      api_type: "account",
      action: "balance"
    })
    balance_details = call_secret_api(get_balance_url)
  end

  def info(market_name=VipBot::MARKET_NAME)
    market_summary_url = get_url(
      {
        api_type: "public",
        action: "ticker",
        market: market_name
      }
    )
    summary = self.ticker
    low_24_hr, high_price, ask_price, bid_price = summary["low"].to_i, summary["high"].to_i, summary["sell"].to_i, summary["buy"].to_i

    account = self.account
    idr_balance = account['balance']['idr']
    btc_balance = account['balance']['btc']

    text_info = "VIP INFO\n\n"
    text_info += "IDR Balance: Rp #{idr_balance}\n"
    text_info += "BTC Balance: #{btc_balance}\n"
    text_info += "\n\nVIP MARKET INFO\n\n"
    text_info += "High Price: Rp #{high_price}\n"
    text_info += "Low Price: Rp #{low_24_hr}\n"
    text_info += "Ask Price: Rp #{ask_price}\n"
    text_info += "Bid Price: Rp #{bid_price}\n"

    text_info
  end
end

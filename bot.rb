require 'dotenv/load'
require 'telegram/bot'
require 'mysql2'
require_relative 'arbitrate_bot'

# Define Database Connection
client = Mysql2::Client.new(
  host: ENV['DB_HOST'],
  username: ENV['DB_USERNAME'],
  password: ENV['DB_PASSWORD'],
  database: ENV['DB_NAME']
)

# Define Variable
command, flag = nil
object = {}

def info(client, user_id)
  sql_lot = "SELECT * FROM tbl_lots WHERE user_id='#{user_id}'"
  sql_spread = "SELECT * FROM tbl_spreads WHERE user_id='#{user_id}'"

  lot = client.query(sql_lot).first
  spread = client.query(sql_spread).first

  text = "<b>Setting Information</b> \n\n"
  text += "<b>Lot Coin:</b> #{lot.nil? ? '-' : lot['quantity']} \n"
  text += "<b>Spread Coin:</b> #{spread.nil? ? '-' : spread['spread_value']} \n"

  text
end

def startrade(client, user_id)
  sql_lot = "SELECT * FROM tbl_lots WHERE user_id='#{user_id}'"
  sql_spread = "SELECT * FROM tbl_spreads WHERE user_id='#{user_id}'"

  lot = client.query(sql_lot).first
  spread = client.query(sql_spread).first

  if !lot.nil? && !spread.nil?
    arbitrate = ArbitrateBot.new
    arbitrate.trade!(lot['quantity'], 13900, spread['spread_value'])
  end
end

Telegram::Bot::Client.run(ENV['TELEGRAM_TOKEN']) do |bot|
  begin
    bot.listen do |message|

      # Set Coin Lot
      if command.eql?('setlot')
        sql = "SELECT * FROM tbl_lots WHERE user_id='#{message.from.id}'"
        result = client.query(sql).first

        flag = result.nil? ? 'new' : 'edit'
        time_at = Time.now

        if flag.eql?('new')
          sql = "INSERT INTO tbl_lots (user_id, quantity, created_at, updated_at) VALUES ('#{message.from.id}','#{message.text}', '#{time_at}', '#{time_at}')"
        else
          sql = "UPDATE tbl_lots SET quantity = '#{message.text}', updated_at = '#{time_at}' WHERE user_id = '#{message.from.id}'"
        end

        result = client.query(sql)

        text = 'Data successfully saved.'
        bot.api.send_message(chat_id: message.chat.id, text: text)

        # Reset var from previous command
        command, flag = nil
      end

      # Set Sread
      if command.eql?('setspread')
        sql = "SELECT * FROM tbl_spreads WHERE user_id='#{message.from.id}'"
        result = client.query(sql).first

        flag = result.nil? ? 'new' : 'edit'
        time_at = Time.now

        if flag.eql?('new')
          sql = "INSERT INTO tbl_spreads (user_id, spread_value, created_at, updated_at) VALUES ('#{message.from.id}','#{message.text}', '#{time_at}', '#{time_at}')"
        else
          sql = "UPDATE tbl_spreads SET spread_value = '#{message.text}', updated_at = '#{time_at}' WHERE user_id = '#{message.from.id}'"
        end

        result = client.query(sql)

        text = 'Data successfully saved.'
        bot.api.send_message(chat_id: message.chat.id, text: text)

        # Reset var from previous command
        command, flag = nil
      end

      case message
      when Telegram::Bot::Types::Message
        case message.text
        when '/start'
          text = "Welcome, #{message.from.first_name}! \n\n"
          text += "To get familiar with Bot, use /help command. \n\n"

          bot.api.send_message(chat_id: message.chat.id, text: text)
        when '/startrade'
          text = "Lets start Trading! \n\n"
          text += "This process will take a while, please wait"
          bot.api.send_message(chat_id: message.chat.id, text: text)

          trade = startrade(client, message.from.id)
          bot.api.send_message(chat_id: message.chat.id, text: trade, parse_mode: 'HTML')
        when '/balance'
          arbitrate = ArbitrateBot.new
          text = arbitrate.balance

          bot.api.send_message(chat_id: message.chat.id, text: text, parse_mode: 'HTML')
        when '/setlot'
          # Reset var from previous command
          command, flag = nil

          text = 'Please choose lot coin:'
          options = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(0.0015),%w(0.0016),%w(0.0017),%w(0.0018),%w(0.0019),%w(0.002)], one_time_keyboard: true)
          bot.api.send_message(chat_id: message.chat.id, text: text, reply_markup: options)

          command = 'setlot'
        when '/setspread'
          # Reset var from previous command
          command, flag = nil

          text = 'Please choose spread:'
          options = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(0.01),%w(0.02),%w(0.03),%w(0.04),%w(0.05)], one_time_keyboard: true)
          bot.api.send_message(chat_id: message.chat.id, text: text, reply_markup: options)

          command = 'setspread'
        when '/info'
          text = info(client, message.from.id)
          bot.api.send_message(chat_id: message.chat.id, text: text, parse_mode: 'HTML')
        when '/help'
          text = "You can control me by sending these commands:\n\n"
          text += "/start - Start a Bot\n"
          text += "/setlot - Change lot coin\n"
          text += "/setspread - Change spread coin\n"
          text += "/info - Get your setting info\n"
          text += "/balance - Get balance information from VIP and BINANCE\n"
          text += "/startrade - Start trading\n"

          bot.api.send_message(chat_id: message.chat.id, text: text)
        end
      end
    end
  rescue => e
    puts e.inspect
    retry
  end
end

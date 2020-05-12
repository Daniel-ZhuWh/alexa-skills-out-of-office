require "sinatra"
require 'twilio-ruby'

# Load environment variables using Dotenv. If a .env file exists, it will
# set environment variables from that file (useful for dev environments)
configure :development do
  require 'dotenv'
  Dotenv.load
end

def send_prompts message, to_number
	client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
	# Include a message here

	# this will send a message from any end point
	client.api.account.messages.create(
		from: ENV["TWILIO_FROM"],
		to: to_number,
		body: message
	)
end

desc "sends breakfast prompt"
task :send_breakfast_prompt do
    # need to add the details for who the
    # sender is
  reminder = "Morning!☀\nHave you had your breakfast yet? If so, you can say 'track meal' to log it."
  sender = ENV["TEST_NUMBER"]
  send_prompts reminder, sender
  puts "message sent"
  # sleep(3)
  # send_sms_to sender, "Good morning! Here's a fun one for you:\n" + drawing_prompt
end

desc "sends lunch prompt"
task :send_lunch_prompt do
    # need to add the details for who the
    # sender is
  reminder = "Hi there!😘\nHave you had your lunch yet? If so, you can say 'track meal' to log it."
  sender = ENV["TEST_NUMBER"]
  send_prompts reminder, sender
  puts "message sent"
  # sleep(3)
  # send_sms_to sender, "Good morning! Here's a fun one for you:\n" + drawing_prompt
end

desc "sends dinner prompt"
task :send_dinner_prompt do
    # need to add the details for who the
    # sender is
  reminder = "Good evening!🌙\nHave you had your dinner yet? If so, you can say 'track meal' to log it."
  sender = ENV["TEST_NUMBER"]
  send_prompts reminder, sender
  puts "message sent"
  # sleep(3)
  # send_sms_to sender, "Good morning! Here's a fun one for you:\n" + drawing_prompt
end

task :test do
  puts "testing..."
  # NewsFeed.update
  puts "done."
end

require "sinatra"
# require 'sinatra/reloader' if development?

require 'alexa_skills_ruby'
require 'httparty'
require 'iso8601'
require 'twilio-ruby'
require 'json'
# require 'whenever'

$current_sender = ''
# ----------------------------------------------------------------------

# Load environment variables using Dotenv. If a .env file exists, it will
# set environment variables from that file (useful for dev environments)
configure :development do
  require 'dotenv'
  Dotenv.load
end

# enable sessions for this project
enable :sessions

def update_log cal, pro, fat
  obj = JSON.parse(IO.read('food_log.json'))
  obj['cal_sum'] += cal
  obj['pro_sum'] += pro
  obj['fat_sum'] += fat
  File.open("food_log.json","w") do |f|
    f.write(obj.to_json)
  end
end

def get_summary
  motivate_quotes = ['The Struggle You Are In Today Is Developing The Strength You Need for Tomorrow',
  'The Road May Be Bumpy But Stay Committed To The Process',
  'If You Are Tired Of Starting Over, Stop Giving Up',
  'It’s Not A Diet, It’s A Lifestyle Change',
  'Will Is A Skill',
  'Stressed Spelled Backwards Is Desserts. Coincidence? I think not!',
  'Strive For Progress, Not Perfection',
  'Success Is Never Certain, Failure Is Never Final',
  'A Goal Without A Plan Is Just A Wish']

  obj = JSON.parse(IO.read('food_log.json'))
  cal_sum = obj['cal_sum']
  cal_limit = obj['cal_limit']
  dif = (cal_limit - cal_sum)/cal_limit

  if dif < -0.25
    message = "You've exceeded your daily calorie limit a lot! \n"+ motivate_quotes.sample + "\nDon't worry, I'm here for you"
  elsif dif < 0
    message = "You've run out of your calorie limit for the day. Don't forget your plans~"
  elsif dif < 0.15
    message = "You have less than 300 calories left for your daily limit. That's about the amount of a light breakfast."
  elsif dif < 0.25
    message = "You have less than 500 calories left for your daily limit. That's about a hamburger, but I'm not suggesting you to eat that!"
  else
    message = "You have more than 500 calories left for your daily limit. That's more than a proper meal. Go ahead and enjoy the food!"
  end
  return message
end

def determine_response body
	#customize response message according to user input
  puts session[:last_msg]
	#keyword lists
	greeting_kwd = ['hi', 'hello', 'hey']
	who_kwd = ['who']
	what_kwd = ['what', 'features', 'functions', 'actions', 'help']
	where_kwd = ['where']
	when_kwd = ['when', 'time']
	why_kwd = ['why']
	joke_kwd = ['joke']
	fact_kwd = ['fact']
	funny_kwd = ['lol', 'haha', 'hh']
  weather_kwd = ['weather']
  diet_kwd = ['track diet', 'track', 'log']
  summary_kwd = ['summary', 'summarize']

	body = body.downcase.strip
  if session[:last_msg] == 'default'
    if include_keywords body, greeting_kwd
  		message = "Hi there, it's Diet Bot. My app helps you log your meals.\n
      Start by saying 'Track meal'."
  	elsif include_keywords body, who_kwd
  		message = "It's Diet Bot created by Daniel here!\n
  						If you want to know more about me, you can say 'fact'."
  	elsif include_keywords body, what_kwd
  		message = "I'm Diet Bot and can help you log your meals.\n
      Start by saying 'Track meal'."
  	elsif include_keywords body, where_kwd
  		message = "I'm in Pittsburgh~<br>"
  	elsif include_keywords body, when_kwd
  		message = "The bot is made in Spring 2020.<br>"
  	elsif include_keywords body, why_kwd
  		message = "It was made for class project of 49714-pfop.<br>"
  	elsif include_keywords body, joke_kwd
  		array_of_lines = IO.readlines("jokes.txt")
  		message = array_of_lines.sample
  	elsif include_keywords body, fact_kwd
  		array_of_lines = IO.readlines("facts.txt")
  		message = array_of_lines.sample
  	elsif include_keywords body, funny_kwd
  		message = "Nice one right lol."
    elsif include_keywords body, summary_kwd
      message = get_summary
    elsif include_keywords body, diet_kwd
      session[:last_msg] = 'log_meal'
      message = "Sure, what food did you have?"
  	else
      message = "Sorry, your input cannot be understood by the bot.<br>
  						Try using two parameters called Body and From."
    end

  # meal logging
  elsif session[:last_msg] == 'log_meal' || session[:last_msg] == 'further_log_meal'
    temp = get_nutrients body
    send_sms temp, $current_sender
    if session[:last_msg] != 'further_log_meal'
      session[:last_msg] = 'default'
    end
    message = get_summary
	end
  puts "modified" + session[:last_msg]
  message
  return message
end

def include_keywords body, keywords
	# check if string contains any word in the keywords array
	keywords.each do |keyword|
		# puts "now checking" + keyword
		if body.downcase.include?(keyword)
			return true
		end
  end
	return false
end

def get_nutrients body
  url = 'https://trackapi.nutritionix.com/v2/natural/nutrients'
  puts body
  res = HTTParty.post url, body: { query:body, timezone: "US/Eastern"}.to_json, headers: {'content-type' => 'application/json', 'x-app-id' => ENV['NUTRITIONIX_ID'], 'x-app-key' => ENV['NUTRITIONIX_KEY']}

  total_fat = 0
  total_protein = 0
  total_cal = 0
  if res['foods'].nil?
    msg = "I can't seem to recognize any food in what you said. Can you be more specific please?"
    session[:last_msg] = "further_log_meal"
    return msg
  else
    res['foods'].each do |food|
      total_fat += food['nf_total_fat']
      total_protein += food['nf_protein']
      total_cal += food['nf_calories']
    end
    #save changes to json file
    update_log total_cal, total_protein, total_fat

    total_fat = total_fat.to_i
    total_protein = total_protein.to_i
    total_cal = total_cal.to_i

    msg = "You consumed approximately #{total_cal} calories in total with #{total_protein} grams of protein and #{total_fat} grams of fat."
    return msg
  end
end

def send_sms message, to_number
	client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
	# Include a message here

	# this will send a message from any end point
	client.api.account.messages.create(
		from: ENV["TWILIO_FROM"],
		to: to_number,
		body: message
	)
end


class CustomHandler < AlexaSkillsRuby::Handler

  on_launch() do
    response.set_output_speech_text("Hi there, I'm your diet bot.")
    logger.info 'Lauch request processed'
    response.should_end_session = false
  end

  on_intent("REQUEST_TO_LOG_MEAL") do
    # add a response to Alexa
    response.set_output_speech_text("Sure, what food did you have?")
    # create a card response in the alexa app
    response.set_simple_card("Diet Bot App", "Meal logged. Have a nice day!")
    # log the output if needed
    logger.info 'REQUEST_TO_LOG_MEAL processed'
    response.should_end_session = false
    # send a message to slack
    # update_status "DO_NOT_DISTURB"
  end

  on_intent("LOG_MEAL") do
    food_log = request.intent.slots["food_log"]
    # add a response to Alexa
    res = get_nutrients food_log

    response.set_output_speech_text("#{res}")
    # create a card response in the alexa app
    response.set_simple_card("Diet Bot App", "#{res}")
    # log the output if needed
    logger.info "#{res}"
    # send a message to slack
    # update_status "DO_NOT_DISTURB"
  end

  on_intent("AMAZON.HelpIntent") do
    response.set_output_speech_ssml("<speak>You can ask me to log your meal status by saying
      <break time='200ms'/><emphasis level='moderate'>log meal</emphasis>.
      and then saying what food you had <break time='200ms'/>.
      For example, you can say
      <break time='150ms'/>I had an apple for breakfast,
      <break time='100ms'/>or
      <break time='100ms'/>I ate a hamburger just now.
      <break time='150ms'/>Calories and more data about the food will be responded to you.
      </speak>")
    logger.info 'HelpIntent processed'
  end

  # on_intent("BACK_IN") do
  #
	# 	# Access the slots
  #   slots = request.intent.slots
  #   puts slots.to_s
  #
	# 	# Duration is returned in a particular format
	# 	# Called ISO8601. Translate this into seconds
  #   duration = ISO8601::Duration.new( request.intent.slots["duration"] ).to_seconds
  #
	# 	# This will downsample the duration from a default seconds
	# 	# To...
  #   if duration > 60 * 60 * 24
  #     days = duration/(60 * 60 * 24).round
  #     response.set_output_speech_text("I've set you away for #{ days } days")
  #   elsif duration > 60 * 60
  #     hours = duration/(60 * 60 ).round
  #     response.set_output_speech_text("I've set you away for #{ hours } hours")
  #   else
  #     mins = duration/(60).round
  #     response.set_output_speech_text("I've set you away for #{ mins } minutes")
  #   end
  #   logger.info 'BackIn processed'
  #   update_status "BACK_IN", duration
  # end
  #
  # on_intent("TEST") do
  #   response.set_output_speech_ssml("<speak>
  #   Welcome to Car-Fu.
  #   <audio src='soundbank://soundlibrary/transportation/amzn_sfx_car_accelerate_01' />
  #   You can order a ride, or request a fare estimate.
  #   Which will it be?
  #   </speak>")
  #
  #   logger.info 'TEST processed'
  # end
end

# ----------------------------------------------------------------------
#     ROUTES, END POINTS AND ACTIONS
# ----------------------------------------------------------------------


get '/' do
  404
end

# while true do
#   puts "3 seconds"
#   sleep 3
# end
# THE APPLICATION ID CAN BE FOUND IN THE
# get '/test/scheduler' do
#   while true do
#     puts "3 seconds"
#     sleep 3
#   end
# end

get "/sms/incoming" do
  # sms intercation through twilio
  if session[:last_msg] != 'log_meal' && session[:last_msg] != 'further_log_meal'
    session[:last_msg] = 'default'
  end
  body = params[:Body] || ""
  sender = params[:From] || ""
  $current_sender = sender
  message = determine_response body
  send_sms message, sender
  message
end


post '/incoming/alexa' do
  content_type :json

  handler = CustomHandler.new(application_id: ENV['ALEXA_APPLICATION_ID'], logger: logger)

  begin
    hdrs = { 'Signature' => request.env['HTTP_SIGNATURE'], 'SignatureCertChainUrl' => request.env['HTTP_SIGNATURECERTCHAINURL'] }
    handler.handle(request.body.read, hdrs)
  rescue AlexaSkillsRuby::Error => e
    logger.error e.to_s
    403
  end

end

get "/test/food" do
  url = 'https://trackapi.nutritionix.com/v2/natural/nutrients'

  res = HTTParty.post url, body: { query:"I ate two eggs and one ham.", timezone: "US/Eastern"}.to_json, headers: {'content-type' => 'application/json', 'x-app-id' => 'fdeb15cb', 'x-app-key' => '
  8521704bdf8b2eadfa20a6bd17b043e5'}

  puts res.class
  # puts res.to_json.class
  # obj = JSON.parse(res.body)
  # puts obj.class
  total_fat = 0
  total_protein = 0
  total_cal = 0
  # fat = res['foods'][0]['nf_total_fat'].to_s
  res['foods'].each do |food|
    total_fat += food['nf_total_fat']
    total_protein += food['nf_protein']
    total_cal += food['nf_calories']
  end
  # "You consumed #{total_cal} calories in total with #{total_protein} grams of protein and #{total_fat} grams of fat."
end

# ----------------------------------------------------------------------
#     ERRORS
# ----------------------------------------------------------------------
get "/ini" do
  hash = {
    # "foods" => [],
    "cal_sum" => 0,
    "pro_sum" => 0,
    "fat_sum" => 0,
    "cal_limit" => 2000
  }
  File.open("food_log.json","w") do |f|
    f.write(hash.to_json)
  end
end

get "/clr" do
  obj = JSON.parse(IO.read('food_log.json'))
  # obj['foods'] = []
  obj['cal_sum'] = 0
  obj['pro_sum'] = 0
  obj['fat_sum'] = 0

  File.open("food_log.json","w") do |f|
    f.write(obj.to_json)
  end
end

get "/summary" do
  get_summary
end

error 401 do
  "Not allowed!!!"
end

# ----------------------------------------------------------------------
#   METHODS
#   Add any custom methods below
# ----------------------------------------------------------------------
